#!/usr/bin/env lims-perl

use strict;
use warnings;

use File::Basename;
use File::Path;
use File::Spec;
use List::Util;
use YAML;

use GSCApp;
my $clo = { # command line options
    biosample => { doc => 'Biosample for the submission.', },
    bioproject  => { doc => 'Bioproject for the submission.', },
    output_path  => { doc => 'Directory for run file links and XMLs.', },
    plate_barcodes => { doc => 'Barcode for LIMS containers. Comma separated list.', },
    sample  => { doc => 'The LIMS sample to filter on multi sample runs.', },
    submission_alias  => { doc => 'An alias for the submission.', },
};
my %params = map { $_ => ( exists $clo->{$_}->{value} ? $clo->{$_}->{value} : undef ) } keys %$clo;
App::Getopt->command_line_options(
    (map {
        my $n = $_;
        $n =~ s/_/-/g;
        $n => {
            action => \$params{$_},
            argument => ( $clo->{$_}->{type} ? $clo->{$_}->{type} : '=s' ),
            message => $clo->{$_}->{doc},
        },
    } keys %$clo),
);
App->init;

validate_params(\%params);
get_organism_sample(\%params);
get_pacbio_runs(\%params);
get_analysis_files_from_runs(\%params);
link_analysis_files_to_output_path(\%params);
render_xml(\%params);

sub validate_params {
    my $params = shift;
    print STDERR "Pac Bio Submission...\n";

    my @errors;
    for my $param_name ( keys %$params ) {
        next if defined $params->{$param_name};
        push @errors, "No $param_name given!" if not $params->{$param_name};
    }
    die join("\n", @errors) if @errors;

    File::Path::make_path($params->{output_path}) if not -d $params->{output_path};
    die sprintf('Output path does not exist! %s', $params->{output_path}) if not -d $params->{output_path};

    print STDERR "Params: \n".join("\n", map { sprintf('%17s => %s', $_, $params->{$_}) } sort keys %$params)."\n";
}

sub get_pacbio_runs {
    my $params = shift;
    print STDERR "Get Pac Bio runs...\n";

    my $plate_barcodes_string = $params->{plate_barcodes};
    my @plate_barcodes = split(/[,\s+]/, $plate_barcodes_string);
    my @pacbio_runs = GSC::Equipment::PacBio::Run->get(plate_barcode => \@plate_barcodes);
    die sprintf('No PacBio runs for plate barcodes! %s', join(' ', @plate_barcodes)) if not @pacbio_runs;
    die sprintf('Did not find all PacBio runs for plate barcodes! %s', join("\n", map { YAML::Dump } @pacbio_runs)) if @pacbio_runs != @plate_barcodes;
    printf STDERR "PacBio run ids: %s\n", join(' ', map { $_->id } @pacbio_runs);
    $params->{pacbio_runs} = \@pacbio_runs;
}

sub get_organism_sample {
    my $params = shift;
    my $sample_param = $params->{sample};
    my $sample = GSC::Organism::Sample->get(
        $sample_param =~ /^\d+$/
        ? ( id => $sample_param )
        : ( full_name => $sample_param )
    );
    die sprintf('No sample for %s', $sample_param) if not $sample;
    $params->{sample} = $sample;
}

sub get_analysis_files_from_runs {
    my $params = shift;
    print STDERR "Gathering run files...\n";
    die "No pac bio runs!" if not $params->{pacbio_runs};

    my @files;
    for my $run ( @{$params->{pacbio_runs}} ) {
        my $libraries_and_primary_analyses = GSC::Equipment::PacBio::Run->get_library_to_primary_analysis_map(
            barcodes => [ $run->plate_barcode ],
            organism_sample => $params->{sample}->id,
        );
        if ( not $libraries_and_primary_analyses and not %$libraries_and_primary_analyses ) {
            die sprintf("Did not find primary analysis for %s on run %s!", $params->{sample}->full_name, $run->plate_barcode);
        }
        my @run_files;
        for my $library_name ( keys %$libraries_and_primary_analyses ) {
            for my $primary_analysis ( @{$libraries_and_primary_analyses->{$library_name}} ) {
                for my $file ( map { $_->stringify } $primary_analysis->get_data_files ) {
                    die "Primary analysis file does not exist! $file" if not -s $file;
                    push @run_files, $file;
                }
            }
        }
        die sprintf("Run %s has no primary analysis files!\n", $run->plate_barcode) if not @run_files;
        push @files, @run_files;
    }
    die "No primary analysis files found for any pac bio runs!" if not @files;

    my $max = List::Util::max( map { -s $_ } @files);
    printf STDERR ("Largest file [Kb]: %.0d\n", ($max/1024));

    $params->{analysis_files} = \@files;
}

sub link_analysis_files_to_output_path {
    my $params = shift;
    print STDERR "Linking files...\n";
    die "No analysis files!" if not $params->{analysis_files};

    my $output_path = $params->{output_path};
    for my $file ( @{$params->{analysis_files}} ) {
        my $link = File::Spec->join($output_path, File::Basename::basename($file));
        symlink($file, $link)
            or die sprintf('ERROR: %s. Failed to link %s to %s.', ( $! || 'NA' ), $file, $link);
    }

    print STDERR "Linking files...done\n";
}

sub render_xml {
    my $params = shift;
    print STDERR "Rendering submission XML...\n";

    my $rv = GSC::Equipment::PacBio::Run->render_submission_xml(
        barcodes => [ map { $_->plate_barcode } @{$params->{pacbio_runs}} ],
        organism_sample => $params->{sample},
        bioproject_id => $params->{bioproject},
        biosample_id => $params->{biosample},
        submission_alias => $params->{submission_alias},
        write_tar_file_to_dir => $params->{output_path},
    );
    die 'Failed to create submission XML!' if not $rv;
    die 'Rendered submssion XML, but submission tar file does not exist!' if not -s File::Spec->join($params->{output_path}, $params->{submission_alias}.".tar");

    print STDERR "Rendering submission XML...done\n";
}
