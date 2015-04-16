#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 0.1;

use Data::Dumper;
use IPC::Open3;
use Readonly;
use English '-no_match_vars';
use Carp;

$Data::Dumper::Indent    = 2;
$Data::Dumper::Useqq     = 1;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys  = 1;

sub run_command
{
	my ($command, $input) = @_;

	Readonly my $RETVAL_SHIFT => 8;

	my $pid = open3 my $in, my $out, my $err, $command
	  or croak "could not run $command";

	if (defined $input) {
		if (!print ${in}, $input) {
			printf "Couldn't send data to command\n";
			return (1);
		}
	}

	my @ansout;
	if (defined $out) {
		while (<$out>) {
			chomp;
			push @ansout, $_;
		}
	}

	my @anserr;
	if (defined $err) {
		while (<$err>) {
			chomp;
			push @anserr, $_;
		}
	}

	if (!close $in) {
		printf "Close failed for command\n";
	}
	waitpid $pid, 0;
	my $retval = $CHILD_ERROR >> $RETVAL_SHIFT;

	return ($retval, @ansout, @anserr);
}

sub get_previous
{
	my ($retval, $out, $err) = run_command ('git rev-parse HEAD');

	Readonly my $NO_HEAD    => '4b825dc642cb6eb9a060e54bf8d69288fbee4904';
	Readonly my $NOT_GIT    => 'Not a git repository';
	Readonly my $NO_COMMITS => 'unknown revision';

	if (!defined $out) {
		return;
	}

	if ($retval) {
		if ($out) {
			if ($out =~ /$NOT_GIT/msx) {
				return;
			}

			if ($out =~ /$NO_COMMITS/msx) {
				return $NO_HEAD;
			}
		}

		return;
	}

	if (defined $err) {
		return;
	}

	chomp $out;
	return $out;
}

sub parse_change
{
	my ($str) = @_;

	Readonly my $_OM   => 1;
	Readonly my $_NM   => 2;
	Readonly my $_OH   => 3;
	Readonly my $_NH   => 4;
	Readonly my $_REST => 5;

	my @parts = unpack 'CA[7]A[7]A[41]A[41]A*', $str;

	my $data = {
		old_mode => $parts[$_OM],
		new_mode => $parts[$_NM],
		old_hash => $parts[$_OH],
		new_hash => $parts[$_NH],
	};

	@parts = @parts[$_REST .. $#parts];
	my @p2 = split /\t/msx, $parts[0];

	my $action = $p2[0];
	my $pc;
	if ($action =~ /^(R)(.+)/msx) {
		$action = "$1";
		$pc     = "$2";
	}
	$data->{'action'}   = $action;
	$data->{'filename'} = $p2[1];

	if ($p2[2]) {
		$data->{'rename'} = $p2[2];
	}
	if ($pc) {
		$data->{'similarity'} = $pc;
	}

	return $data;
}

sub get_changes
{
	my $prev = get_previous ();
	if (!$prev) {
		return;
	}

	my ($retval, @out, @err) = run_command ("git diff-index --find-renames --cached $prev");

	if ($retval || @err) {
		return;
	}

	my @changes;
	foreach (@out) {
		push @changes, parse_change ($_);
	}

	return \@changes;
}

sub main
{
	my $changes = get_changes ();
	if (!defined $changes) {
		printf "Not a git repository\n";
		exit 1;
	}

	# printf "count = %d\n", scalar @{$changes};
	if (!scalar @{$changes}) {
		printf "No changes to commit\n";
		exit 1;
	}

	print Dumper $changes;
	return 1;
}


exit main ();

