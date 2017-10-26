package PacBioTestEnv;

use strict;
use warnings 'FATAL';

use Path::Class;
use Test::MockObject;
use Sub::Install;

use lib file(__FILE__)->dir->parent->subdir('lib')->stringify;

sub test_data_directory_for_class {
    file(__FILE__)->dir->subdir('data', join('-', split('::', $_[1])));
}

my $test_run;
sub get_test_run {
    if ( ! $test_run ) {
        PacBioTestEnv->setup_test_run;
    }
    $test_run;
}

sub setup_test_run {
    my $class = shift;

    $test_run = Test::MockObject->new;
    $test_run->set_always('id', '22');
    $test_run->{barcode} = 'A1B2C3';
    $test_run->mock('plate_barcode', sub{ $test_run->{barcode} });

    my $sample = Test::MockObject->new;
    $sample->set_always('full_name', 'H_IJ-HG02818-HG02818_1');
    $test_run->{library} = Test::MockObject->new;
    $test_run->{library}->set_always('find_organism_sample', $sample);

    $test_run->{container} = Test::MockObject->new;
    Sub::Install::reinstall_sub({
        code => sub{ $test_run->{container} },
        as => 'get',
        into => 'GSC::Container',
        });
    my %content;
    push @{$content{1}}, $test_run->{library};
    $test_run->{content} = \%content;
    $test_run->{container}->mock('content', sub{ $test_run->{content} });

    $test_run->{collection} = Test::MockObject->new;
    $test_run->{collection}->set_always('well', 1);
    $test_run->mock('get_collection', sub{ $test_run->{collection} });

    $test_run->{primary_analysis} = Test::MockObject->new;
    my $tmpdir = dir( File::Temp::tempdir(CLEANUP => 1) );
    my $data_dir = $class->test_data_directory_for_class('PacBio::Run');
    my @files = ( map { $data_dir->file($_) } qw{
        m160610_215437_00116_c100976122550000001823226708101630_s1_p0.1.bax.h5
        m160610_215437_00116_c100976122550000001823226708101630_s1_p0.2.bax.h5
        m160610_215437_00116_c100976122550000001823226708101630_s1_p0.3.bax.h5
        m160610_215437_00116_c100976122550000001823226708101630_s1_p0.bas.h5
        m160610_215437_00116_c100976122550000001823226708101630_s1_p0.metadata.xml
    });
    $test_run->{primary_analysis}->mock('get_data_files', sub{ @files });
    $test_run->{collection}->set_always('get_primary_analysis', $test_run->{primary_analysis});

    $test_run->{dna_location} = Test::MockObject->new;
    $test_run->{dna_location}->set_always('dl_id', 1);
    Sub::Install::reinstall_sub({
        code => sub{ $test_run->{dna_location} },
        as => 'get',
        into => 'GSC::DNALocation',
        });

}

1;
