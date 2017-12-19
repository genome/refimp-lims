package PacBio::Run::View;

use strict;
use warnings 'FATAL';

use PacBio::Run;
use YAML;

sub help { return 'show details for a run' }
sub properties {
    {
        barcode => { doc => 'Barcode for LIMS containers.', },
    },
}

sub new {
    my ($class, %params) = @_;
    die "No barcode given to view run!" if not $params{barcode};
    bless \%params, $class;
}

sub execute {
    my $self = shift;

    my $barcode = $self->{barcode};
    my $run = GSC::Equipment::PacBio::Run->get(plate_barcode => $barcode);
    printf(STDERR "No run for barcode %s", $barcode) and next BARCODE if not $run;

    my $samples_and_analysis_files = PacBio::Run->samples_and_analysis_files($run);
    print YAML::Dump({
        run_id => $run->id,
        barcode => $barcode,
        samples_and_analysis_files => $samples_and_analysis_files,
        });
}

1;
