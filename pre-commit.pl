#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 0.1;

use Data::Dumper;
use IPC::Open3;
use Readonly;

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

sub get_changes
{
	my $prev = get_previous();
	if (!$prev) {
		return;
	}

	my ($retval, @out, @err) = run_command ("git diff-index --find-renames --cached --name-status $prev");

	return \@out;
}


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

foreach (@{$changes}) {
	my ($type, $file, $rename) = split "\t", $_;

	if ($type =~ /^R/) {
		$file = $rename;
	}
	printf ">>%s<< >>%s<<\n", $type, $file;
}

exit 1;

# 	TYPE="${FILE:0:1}"
# 	# [ "$TYPE" = "D" ] && continue	# Ignore deleted files

# 	FILE="${FILE#*	}"
# 	# [ $TYPE = "R" ] && FILE="${FILE#*	}"
# 	echo "<<$TYPE>>	>>$FILE<<"

# :100644 000000 637a09b86af61897fb72f26bfb874f2ae726db82 0000000000000000000000000000000000000000 D	banana.doc
# :100644 100644 44a910549f687b3a5ae95900f1c1882b235e9ed5 2f37c4fb627f1745e28293ef08c3f324b3ab8b48 M	cherry.pdf
# :000000 100644 0000000000000000000000000000000000000000 c933481298902a08032773cfbb62eeebeec72f37 A	endive.avi
# :100644 100644 4c479defff9a675f4fa1a8867096d90733e9b769 4c479defff9a675f4fa1a8867096d90733e9b769 R100	apple.txt	pineapple.txt
# :100755 100755 0a177122eddc779f29690106a62489d98450f73a 817dd879810b68c0826464ed3f4793ccd7704423 M	pre-commit
