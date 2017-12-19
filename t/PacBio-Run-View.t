#!/usr/bin/env lims-perl

use strict;
use warnings 'FATAL';

use Test::Exception;
use Test::More tests => 3;
use PacBioTestEnv;

my $pkg = 'PacBio::Run::View';
use_ok($pkg) or die;

subtest 'fails' => sub{
    plan tests => 1;

    throws_ok(sub{ $pkg->new; }, qr/No barcode given to view run/, 'fails w/o barcode');

};

subtest 'execute' => sub{
    plan tests => 3;

    my $test_run = PacBioTestEnv->get_test_run;
    my $barcode = $test_run->plate_barcode;
    my $cmd = $pkg->new(barcode => $barcode);
    ok($cmd, 'new');

    my $output;
    open local(*STDOUT), '>', \$output or die $!;
    ok($cmd->execute, 'execute');
    my $expected_output = qr/\-\-\-\nbarcode\:\ $barcode/;
    like($output, $expected_output, 'output matches');

};

done_testing();
