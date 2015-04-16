#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 0.1;

use Data::Dumper;
use IPC::Open3;
use Readonly;

$Data::Dumper::Indent    = 2;
$Data::Dumper::Useqq     = 1;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys  = 1;

sub run_command
{
	my ($command, $input) = @_;

	my $pid = open3 my $in, my $out, my $err, $command
		or die "could not run $command";

	if (defined $input) {
		print $in $input;
	}

	my @ansout;
	my @anserr;

	if (defined $out) {
		while (<$out>) {
			chomp;
			push @ansout, $_;
		}
	}

	if (defined $err) {
		while (<$err>) {
			chomp;
			push @anserr, $_;
		}
	}

	close ($in);

	waitpid ($pid, 0);
	my $retval = $? >> 8;

	return ($retval, @ansout, @anserr);
}

sub get_previous
{
	my ($retval, $out, $err) = run_command ("git rev-parse HEAD");

	Readonly my $NO_HEAD    => "4b825dc642cb6eb9a060e54bf8d69288fbee4904";
	Readonly my $NOT_GIT    => "Not a git repository";
	Readonly my $NO_COMMITS => "unknown revision";

	if (!defined $out) {
		return;
	}

	if ($retval) {
		if ($out) {
			if ($out =~ /$NOT_GIT/) {
				return;
			}

			if ($out =~ /$NO_COMMITS/) {
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

	my @parts = unpack ("CA[7]A[7]A[41]A[41]A*", $str);

	my $data = {
		old_mode => $parts[1],
		new_mode => $parts[2],
		old_hash => $parts[3],
		new_hash => $parts[4],
	};

	@parts = @parts[5 .. $#parts];
	my @p2 = split '\t', $parts[0];

	my $action = $p2[0];
	my $pc;
	if ($action =~ /^(R)(.+)/) {
		$action = "$1";
		$pc = "$2";
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
	my $prev = get_previous();
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
	my $changes = get_changes();
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
}


return main ();

