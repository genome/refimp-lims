#!/usr/bin/env lims-perl

use strict;
use warnings 'FATAL';

use List::MoreUtils;
use Set::Scalar;
use YAML;

use GSCApp;
App->init;

die "No run barcodes given!" if not @ARGV;

my $barcodes = Set::Scalar->new(@ARGV);
my $found_barcodes = Set::Scalar->new;
BARCODE: for my $barcode ( $barcodes->members ) {
    my $run = GSC::Equipment::PacBio::Run->get(plate_barcode => $barcode);
    next BARCODE if not $run;
    $found_barcodes->insert($barcode);

    my $con = GSC::Container->get(barcode => $run->plate_barcode);
    my $content = $con->content;

    my @s;
    for my $col ( sort { $a->well cmp $b->well } $run->get_collection ) {
        my $dl = GSC::DNALocation->get(
            location_name => lc($col->well),
            location_type => '96 well plate',
        ) or die "col well did not map to dl";

        push @s, $content->{$dl->dl_id}->[0]->dna_name;
    }

    print YAML::Dump({
        run_id => $run->id,
        barcode => $barcode,
        libraries => [ List::MoreUtils::uniq(@s) ],
        has_files => ( $run->get_primary_analysis_data_files ? 1 : 0 ),
    });
}

my $not_found_barcodes = $barcodes->difference($found_barcodes);
print STDERR "Did not find runs for these bacodes: $not_found_barcodes\n" if $not_found_barcodes->members;
exit;
