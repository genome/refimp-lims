package PacBio::Run;

use strict;
use warnings 'FATAL';

sub samples_and_analysis_files {
    my ($class, $run) = @_;

    die "No run given to samples_and_analysis_files" if not $run;

    my $barcode = $run->plate_barcode;
    die sprintf("No plate barcode for run %s", $run->id) if not $barcode;
    my $container = GSC::Container->get(barcode => $barcode);
    die "No container for plate barcode $barcode" if not $container;
    my $content = $container->content;
    die "No content for container with barcode $barcode" if not $content;
    my $collection = $run->get_collection;
    die sprintf('No collection for run with barcode %s', $barcode) if not $collection;

    my %samples_and_analysis_files;
    for my $col ( sort { $a->well cmp $b->well } $collection ) {
        my $dl = GSC::DNALocation->get(
            location_name => lc($col->well),
            location_type => '96 well plate',
        );
        die sprintf("No DNA location for column well %s", $col->well) if not $dl;

        my $library = $content->{$dl->dl_id}->[0];
        my $sample = $library->find_organism_sample;

        my $primary_analysis = $col->get_primary_analysis;
        die sprintf("Run %s has no primary analysis", $run->plate_barcode) if not $primary_analysis;

        my @analysis_files;
        for my $file ( map { $_->stringify } $primary_analysis->get_data_files ) {
            die "Primary analysis file does not exist! $file" if not -s $file;
            push @analysis_files, $file;
        }
        push @{$samples_and_analysis_files{$sample->full_name}}, @analysis_files;
    }

    \%samples_and_analysis_files;
}

1;
