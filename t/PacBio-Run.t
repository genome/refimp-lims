#!/usr/bin/env lims-perl

use strict;
use warnings 'FATAL';

use File::Temp;
use PacBioTestEnv;
use Path::Class;
use Test::MockObject;
use Test::Exception;
use Test::More tests => 3;
use Sub::Install;

use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;

my $pkg = 'PacBio::Run';
use_ok($pkg) or die;

subtest 'samples_and_analysis_files errors' => sub{
    plan tests => 5;

    throws_ok(sub{ $pkg->samples_and_analysis_files; }, qr/No run given/, 'samples_and_analysis_files fails w/o run');

    my $run = PacBioTestEnv->get_test_run;
    my $barcode = $run->{barcode};
    $run->{barcode} = undef;
    throws_ok(sub{ $pkg->samples_and_analysis_files($run); }, qr/No plate barcode for run 22/, 'fails when no barcode');
    $run->{barcode} = $barcode;

    my $container = $run->{container};
    $run->{container} = undef;
    throws_ok(sub{ $pkg->samples_and_analysis_files($run); }, qr/No container for plate barcode/, 'samples_and_analysis_files fails when no container');
    $run->{container} = $container;

    my $content = $run->{content};
    $run->{content} = undef;
    throws_ok(sub{ $pkg->samples_and_analysis_files($run); }, qr/No content for container/, 'samples_and_analysis_files fails when no content');
    $run->{content} = $content;

    my $collection = $run->{collection};
    $run->{collection} = undef;
    throws_ok(sub{ $pkg->samples_and_analysis_files($run); }, qr/No collection for run/, 'samples_and_analysis_files fails when no run collection');
    $run->{collection} = $collection;

};

subtest 'samples_and_analysis_files' => sub{
    plan tests => 3;

    my $run = PacBioTestEnv->get_test_run;
    my $saf;
    lives_ok(sub{ $saf = $pkg->samples_and_analysis_files($run); }, 'samples_and_analysis_files');
    ok($saf, 'got samples_and_analysis_files');
    my %expected_saf = (
        $run->{library}->find_organism_sample->full_name => [ $run->{collection}->get_primary_analysis->get_data_files ],
    );
    is_deeply($saf, \%expected_saf, 'expected samples_and_analysis_files');

};

done_testing();
