#!/usr/bin/perl
# The release of CHANGELOG and of Wolly.Version are the same:
# the number in the
# first line of CHANGELOG, "wolly (X.Y.Z) stable; urgency=low", against the
# one literal that release() of src/Wolly/Version.hiq returns.  Exit 0 when
# they agree, 1 when not, 9 when a file or a number is missing.
#
#     perl scripts/check-version.pl [TAG]
#
# With TAG (v0.1.0) the number must be the tag without its v as well.
use strict;
use warnings;

sub slurp {
	my ($path) = @_;
	open(my $in, '<', $path) or do { print STDERR "ABORT: $path not readable -- nothing was checked\n"; exit 9 };
	local $/;
	my $t = <$in>;
	close $in;
	return $t;
}

my $log = slurp('CHANGELOG');
my ($logged) = $log =~ /\Awolly \((\d+\.\d+\.\d+)\) stable; urgency=low\n/;
defined $logged or do { print STDERR "ABORT: the first line of CHANGELOG names no release -- nothing was checked\n"; exit 9 };
my $body = slurp('src/Wolly/Version.hiq');
my @coded = $body =~ /function release\(\): Span\[Nat8, Static\] is\n\s+return "(\d+\.\d+\.\d+)";/g;
@coded == 1 or do { print STDERR "ABORT: Wolly.Version has " . scalar(@coded) . " release literals, not 1 -- nothing was checked\n"; exit 9 };
my $bad = 0;
if ($coded[0] ne $logged) {
	print "version: CHANGELOG $logged, Wolly.Version $coded[0]\n";
	$bad = 1;
}
if (@ARGV) {
	my ($tagged) = $ARGV[0] =~ /\Av(\d+\.\d+\.\d+)\z/;
	defined $tagged or do { print STDERR "ABORT: $ARGV[0] is no tag vX.Y.Z -- nothing was checked\n"; exit 9 };
	if ($tagged ne $logged) {
		print "version: tag $tagged, CHANGELOG $logged\n";
		$bad = 1;
	}
}
print "version: $logged in CHANGELOG and Wolly.Version" . (@ARGV ? " and the tag" : "") . "\n" unless $bad;
exit $bad;
