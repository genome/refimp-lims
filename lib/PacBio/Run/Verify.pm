package PacBio::Run::Verify;

use strict;
use warnings 'FATAL';

use Set::Scalar;

sub help { 'check run barcode samples and analysis files' }
sub properties {
    {
        barcodes => { doc => 'Barcodes for LIMS containers to verify. Comma separated list.', },
        detail => { doc => 'Show sample barcodes and  analysis files', },
    },
}

sub new {
    my ($class, %params) = @_;

    if ( not $params{barcodes} ) {
        die "No barcodes given to verify!";
    }

    $params{barcodes} = Set::Scalar->new( split(',', $params{barcodes}) );

    bless \%params, $class;
}

sub execute {
    my $self = shift;

    my %samples;
    my @missing_barcodes;
    BARCODE: for my $barcode ( $self->{barcodes}->members ) {
        my $run = GSC::Equipment::PacBio::Run->get(plate_barcode => $barcode);
        if ( not $run ) {
            push @missing_barcodes, $barcode;
            next BARCODE;
        }
        my $samples_and_analysis_files = PacBio::Run->samples_and_analysis_files($run);
        for my $sample ( keys %$samples_and_analysis_files ) {
            push @{$samples{$sample}->{barcodes}}, $barcode;
            my $files = $samples_and_analysis_files->{$sample};
            push @{$samples{$sample}->{analysis_files}}, @{$files->{analysis_files}} if exists $files->{analysis_files};
            push @{$samples{$sample}->{missing_files}}, @{$files->{missing_files}} if exists $files->{missing_files};
        }
    }

    my %output;
    for my $sample ( keys %samples ) {
        my @errors;
        push @errors, 'not_on_all_barcodes' if ! exists $samples{$sample}->{barcodes}
            or $self->{barcodes}->difference( Set::Scalar->new( @{$samples{$sample}->{barcodes}}) );
        push @errors, 'missing_analysis_files' if exists $samples{$sample}->{missing_files};

        my %report = (
            status => ( @errors ? 'ERROR' : 'OK' ),
        );
        $report{errors} = \@errors if @errors;
        $report{info} = $samples{$sample} if $self->{detail};
        $output{$sample} = \%report;
    }

    print YAML::Dump(\%output);
}

1;
