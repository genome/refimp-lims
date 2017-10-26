#!/usr/bin/env lims-perl

use strict;
use warnings 'FATAL';

use File::Temp;
use Path::Class;
use Test::MockObject;
use Test::Exception;
use Test::More tests => 3;
use Sub::Install;

use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;

my %test = ( pkg => 'PacBio::Run' );
subtest 'setup' => sub{
    plan tests => 1;

    use_ok($test{pkg}) or die;

    $test{run} = Test::MockObject->new;
    $test{run}->set_always('id', '22');
    $test{barcode} = 'A1B2C3';
    $test{run}->mock('plate_barcode', sub{ $test{barcode} });

    my $sample = Test::MockObject->new;
    $sample->set_always('full_name', 'H_IJ-HG02818-HG02818_1');
    $test{library} = Test::MockObject->new;
    $test{library}->set_always('find_organism_sample', $sample);

    $test{container} = Test::MockObject->new;
    Sub::Install::reinstall_sub({
        code => sub{ $test{container} },
        as => 'get',
        into => 'GSC::Container',
        });
    my %content;
    push @{$content{1}}, $test{library};
    $test{content} = \%content;
    $test{container}->mock('content', sub{ $test{content} });

    $test{collection} = Test::MockObject->new;
    $test{collection}->set_always('well', 1);
    $test{run}->mock('get_collection', sub{ $test{collection} });

    my $primary_analysis = Test::MockObject->new;
    my $tmpdir = dir( File::Temp::tempdir(CLEANUP => 1) );
    my $data_dir = file(__FILE__)->dir->subdir('data', join('-', split('::', $test{pkg})));
    my @files = ( map { $data_dir->file($_) } qw{
        m160610_215437_00116_c100976122550000001823226708101630_s1_p0.1.bax.h5
        m160610_215437_00116_c100976122550000001823226708101630_s1_p0.2.bax.h5
        m160610_215437_00116_c100976122550000001823226708101630_s1_p0.3.bax.h5
        m160610_215437_00116_c100976122550000001823226708101630_s1_p0.bas.h5
        m160610_215437_00116_c100976122550000001823226708101630_s1_p0.metadata.xml
    });
    $primary_analysis->mock('get_data_files', sub{ @files });
    $test{collection}->set_always('get_primary_analysis', $primary_analysis);

    $test{dna_location} = Test::MockObject->new;
    $test{dna_location}->set_always('dl_id', 1);
    Sub::Install::reinstall_sub({
        code => sub{ $test{dna_location} },
        as => 'get',
        into => 'GSC::DNALocation',
        });

};

subtest 'samples_and_analysis_files errors' => sub{
    plan tests => 5;

    throws_ok(sub{ $test{pkg}->samples_and_analysis_files; }, qr/No run given/, 'samples_and_analysis_files fails w/o run');

    my $barcode = $test{run}->plate_barcode;
    $test{run}->set_always('plate_barcode', undef);
    throws_ok(sub{ $test{pkg}->samples_and_analysis_files($test{run}); }, qr/No plate barcode for run 22/, 'fails when no barcode');
    $test{run}->set_always('plate_barcode', $barcode);

    my $container = delete $test{container};
    throws_ok(sub{ $test{pkg}->samples_and_analysis_files($test{run}); }, qr/No container for plate barcode/, 'samples_and_analysis_files fails when no container');
    $test{container} = $container;

    my $content = delete $test{content};
    throws_ok(sub{ $test{pkg}->samples_and_analysis_files($test{run}); }, qr/No content for container/, 'samples_and_analysis_files fails when no content');
    $test{content} = $content;

    my $collection = delete $test{collection};
    throws_ok(sub{ $test{pkg}->samples_and_analysis_files($test{run}); }, qr/No collection for run/, 'samples_and_analysis_files fails when no run collection');
    $test{collection} = $collection;

};

subtest 'samples_and_analysis_files' => sub{
    plan tests => 3;

    my $saf;
    lives_ok(sub{ $saf = $test{pkg}->samples_and_analysis_files($test{run}); }, 'samples_and_analysis_files');
    ok($saf, 'got samples_and_analysis_files');
    my %expected_saf = (
        $test{library}->find_organism_sample->full_name => [ $test{collection}->get_primary_analysis->get_data_files ],
    );
    is_deeply($saf, \%expected_saf, 'expected samples_and_analysis_files');

};

done_testing();
