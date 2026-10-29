#!/usr/bin/perl
# The form of what a programme says about itself,
# the text on the standard input:
#
#     perl scripts/about-check.pl line NAME RELEASE NOTICE
#     perl scripts/about-check.pl full NAME RELEASE NOTICE [LIBRARY ...]
#     perl scripts/about-check.pl info NAME RELEASE NOTICE
#     perl scripts/about-check.pl sandbox NAME RELEASE NOTICE
#     perl scripts/about-check.pl --self-test
#
# line: "NAME RELEASE, Copyright (C) NOTICE" and nothing else.  full: version, commit, built,
# compiler, system, a line library for each LIBRARY in that order, the copyright last, every value
# from column 13.  info: the long name, a blank line, then name, version, commit, system, arch,
# config, binary, compiler, host and time.  sandbox:
# the line of the printing process, a blank line, its promises, a blank line, the profile of NAME
# with its promises, its paths sorted and each once, and their number.  Exit 0 when the text has
# the form, 1 when not, 9 on a wrong call.
use strict;
use warnings;

sub pattern {
	my ($mode, $name, $release, $notice, @libraries) = @_;
	my ($n, $r, $c) = (quotemeta($name), quotemeta($release), quotemeta($notice));
	return qr/\A$n $r, Copyright \(C\) $c\n\z/ if $mode eq 'line';
	if ($mode eq 'full') {
		my $libs = join('', map { 'library     ' . quotemeta($_) . ' \S[^\n]*\n' } @libraries);
		return qr/\Aversion     $r\ncommit      \S[^\n]*\nbuilt       \S+\ncompiler    hilde \S+\nsystem      \S+\/\S+\n${libs}copyright   Copyright \(C\) $c\n\z/;
	}
	if ($mode eq 'sandbox') {
		return qr/\Asandbox: +\S[^\n]*\n\n  promises: stdio\n\nsandbox profile "$n" \(\S+\/\S+\)\n  promises: \S[^\n]*\n((?:  (?:unveil|landlock|seatbelt|path): \S+ \([rwxc]+\)\n)*)  paths: (\d+)\n\z/;
	}
	if ($mode eq 'info') {
		return qr/\AWolly: Web-ready, OpenBSD-first, Linear, Lean, Yours\n\nname        $n\nversion     $r\ncommit      \S[^\n]*\nsystem      \S+\narch        \S+\nconfig      \S+\nbinary      \S+\ncompiler    hilde \S+\nhost        \S+\ntime        \S+Z\n\z/;
	}
	return undef;
}

# Whether text has the form of mode, and for sandbox its paths sorted, each once, and counted right.
sub good {
	my ($text, @args) = @_;
	my $p = pattern(@args) or return undef;
	return 0 unless $text =~ $p;
	return 1 unless $args[0] eq 'sandbox';
	my ($block, $count) = ($1, $2);
	my @paths = split /\n/, $block;
	for my $i (1 .. $#paths) {
		return 0 if $paths[$i] le $paths[$i - 1];
	}
	return @paths == $count ? 1 : 0;
}

sub self_test {
	my $full = "version     0.1.0\ncommit      none\nbuilt       2026-10-27T12:00:00Z\ncompiler    hilde 0.9\nsystem      linux/aarch64\nlibrary     libcrypto OpenSSL 3.5.1\ncopyright   Copyright (C) 2026 H Z\n";
	my $info = "Wolly: Web-ready, OpenBSD-first, Linear, Lean, Yours\n\nname        qruri\nversion     0.1.0\ncommit      none\nsystem      linux\narch        aarch64\nconfig      none\nbinary      qruri\ncompiler    hilde 0.9\nhost        h\ntime        2026-10-27T12:00:00Z\n";
	my $sandbox = "sandbox:     no-new-privileges, landlock, seccomp\n\n  promises: stdio\n\nsandbox profile \"hello\" (linux/aarch64)\n  promises: stdio rpath wpath cpath flock unix fattr\n  landlock: . (rwc)\n  landlock: /lib (r)\n  landlock: /usr/lib (r)\n  paths: 3\n";
	my @cases = (
		[1, "qruri 0.1.0, Copyright (C) 2026 H Z\n", 'line', 'qruri'],
		[0, "qruri 0.1.1, Copyright (C) 2026 H Z\n", 'line', 'qruri'],
		[0, "qruri 0.1.0, Copyright (C) 2026 H Z\nmore\n", 'line', 'qruri'],
		[1, $full, 'full', 'x', 'libcrypto'],
		[0, $full, 'full', 'x'],
		[0, $full, 'full', 'x', 'libcrypto', 'sqlcipher'],
		[0, $full =~ s/^library     /library    /mr, 'full', 'x', 'libcrypto'],
		[0, $full =~ s/(copyright[^\n]*\n)/$1extra       y\n/r, 'full', 'x', 'libcrypto'],
		[1, $info, 'info', 'qruri'],
		[0, $info =~ s/\n\nname/\nname/r, 'info', 'qruri'],
		[0, $info =~ s/^time        \S+Z\n//mr, 'info', 'qruri'],
		[1, $sandbox, 'sandbox', 'hello'],
		[0, $sandbox =~ s/(  landlock: \/lib \(r\)\n)/$1$1/r, 'sandbox', 'hello'],
		[0, $sandbox =~ s/  landlock: \. \(rwc\)\n(  landlock: \/lib \(r\)\n)/$1  landlock: . (rwc)\n/r, 'sandbox', 'hello'],
		[0, $sandbox =~ s/paths: 3/paths: 4/r, 'sandbox', 'hello'],
		[0, $sandbox =~ s/\n\nsandbox profile/\nsandbox profile/r, 'sandbox', 'hello'],
		[0, $sandbox, 'sandbox', 'login'],
		[1, $sandbox =~ s/"hello"/"buntipng"/r =~ s/  landlock: \/usr\/lib \(r\)\n/  landlock: \/usr\/lib (r)\n  landlock: <directory-of-FILE> (rwc)\n/r =~ s/paths: 3/paths: 4/r, 'sandbox', 'buntipng'],
		[1, $sandbox =~ s/"hello"/"qruri"/r =~ s/(  promises: )stdio rpath[^\n]*\n(?:  landlock: [^\n]*\n)+  paths: 3/$1stdio\n  paths: 0/r, 'sandbox', 'qruri'],
		[0, $sandbox =~ s/"hello"/"qruri"/r =~ s/(  promises: )stdio rpath[^\n]*\n(?:  landlock: [^\n]*\n)+  paths: 3/$1stdio\n  paths: 1/r, 'sandbox', 'qruri'],
	);
	my ($good, $n) = (0, 0);
	for my $c (@cases) {
		my ($want, $text, $mode, $name, @libs) = @$c;
		$n++;
		my $got = good($text, $mode, $name, '0.1.0', '2026 H Z', @libs) ? 1 : 0;
		if ($got == $want) { $good++ } else { print "self-test case $n: want $want, got $got\n" }
	}
	print "about-check self-test: $good of $n cases\n";
	exit($good == $n ? 0 : 1);
}

self_test() if @ARGV == 1 && $ARGV[0] eq '--self-test';
@ARGV >= 4 or do { print STDERR "ABORT: mode NAME RELEASE NOTICE [LIBRARY ...]\n"; exit 9 };
defined pattern(@ARGV) or do { print STDERR "ABORT: no mode $ARGV[0]\n"; exit 9 };
local $/;
my $text = <STDIN>;
$text = '' unless defined $text;
exit 0 if good($text, @ARGV);
print "about-check $ARGV[0] $ARGV[1]: no form:\n$text";
exit 1;
