#!/usr/bin/env lims-perl

use strict;
use warnings 'FATAL';

use PacBioTestEnv;
use Path::Class;
use Test::Exception;
use Test::More tests => 3;

use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;

my $pkg = 'PacBio';
use_ok($pkg) or die;

subtest 'pacbio' => sub{
    plan tests => 9;

    my $output;
    open local(*STDOUT), '>', \$output or die $!;

    my $rv;
    lives_ok(sub{ $rv = $pkg->run; }, 'pacbio');
    like($output, qr/Valid 'pacbio' sub-commands:\n  run/, 'output');
    is($rv, 0, 'correct return value');

    @ARGV = ('-h');
    $output = '';
    lives_ok(sub{ $rv = $pkg->run; }, 'pacbio -h');
    like($output, qr/Valid 'pacbio' sub-commands:\n  run/, 'output');
    is($rv, 0, 'correct return value');

    @ARGV = ('blah');
    $output = '';
    lives_ok(sub{ $rv = $pkg->run; }, 'pacbio blah');
    like($output, qr/Invalid sub-command for pacbio/, 'output');
    is($rv, 1, 'correct return value');

};

subtest 'pacbio run' => sub{
    plan tests => 9;

    my $output;
    open local(*STDOUT), '>', \$output or die $!;

    my $rv;
    @ARGV = ('run');
    lives_ok(sub{ $rv = $pkg->run; }, 'pacbio run');
    like($output, qr/Valid 'pacbio run' sub\-commands:\nsubmit\s+/, 'output');
    is($rv, 0, 'correct return value');

    @ARGV = (qw/ run -h /);
    $output = '';
    lives_ok(sub{ $rv = $pkg->run; }, 'pacbio run -h');
    like($output, qr/Valid 'pacbio run' sub-commands:\nsubmit\s+/, 'output');
    is($rv, 0, 'correct return value');

    @ARGV = (qw/ run blah /);
    $output = '';
    lives_ok(sub{ $rv = $pkg->run; }, 'pacbio run blah');
    like($output, qr/Invalid sub-command for pacbio run: blah/, 'output');
    is($rv, 1, 'correct return value');

};

done_testing();
