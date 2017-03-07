#!/usr/bin/env lims-perl

use strict;
use warnings;

use File::Basename;
use File::Path;
use File::Spec;
use List::Util;
use YAML;

use GSCApp;
my %params;
my @param_names = (qw/ biosample bioproject output_path sample_id submission_alias /);
my @plate_barcodes;
App::Getopt->command_line_options(
    (map { my $n = $_; $n =~ s/_/-/g; sprintf('%s=s', $n) => \$params{$_} } @param_names),
	"plate-barcodes=s" => \@plate_barcodes,
);
App->init;

my @errors;
for my $param_name ( @param_names ) {
    push @errors, "No $param_name given!" if not $params{$param_name};
}
push @errors, 'No plate barcodes given!' if not @plate_barcodes;
die join("\n", @errors) if @errors;
print STDERR "Params: \n".YAML::Dump(\%params);

my @pacbio_runs = GSC::Equipment::PacBio::Run->get(plate_barcode => \@plate_barcodes);
die sprintf('No PacBio runs for plate barcodes! %s', join(' ', @plate_barcodes)) if not @pacbio_runs;
die sprintf('Did not find all PacBio runs for plate barcodes! %s', join("\n", map { YAML::Dump } @pacbio_runs)) if @pacbio_runs != @plate_barcodes;
printf STDERR "PacBio run ids: %s\n", join(' ', map { $_->id } @pacbio_runs);

my $sample = GSC::Organism::Sample->get($params{sample_id});
die sprintf('No sample for %s', $params{sample_id}) if not $sample;

File::Path::make_path($params{output_path}) if not -d $params{output_path};
die sprintf('Output path does not exist! %s', $params{output_path}) if not -d $params{output_path};

print STDERR "Linking files...\n";
my @files;
for my $pacbio_run ( @pacbio_runs ) {
    for my $file ( $pacbio_run->get_primary_analysis_data_files ) {
        die "File does not exist! $file" if not -s $file;
        push @files, $file;
        my $link = File::Spec->join($params{output_path}, File::Basename::basename($file));
        symlink($file, $link)
            or die sprintf('ERROR: %s. Failed to link %s to %s.', ( $! || 'NA' ), $file, $link);
        #FIXME MD5
    }
}
print STDERR "Linking files...done\n";
my $max = List::Util::max( map { -s $_ } @files);
printf STDERR ("Largest file [Kb]: %.0d\n", ($max/1024));

print STDERR "Rendering submission XML...\n";
my $rv = GSC::Equipment::PacBio::Run->render_submission_xml(
    barcodes => \@plate_barcodes,
    organism_sample => $sample,
    bioproject_id => $params{bioproject},
    biosample_id => $params{biosample},
    submission_alias => $params{submission_alias},
    write_tar_file_to_dir => $params{output_path},
    );
die 'Failed to create submission XML!' if not $rv;
die 'Rendered submssion XML, but submission tar file does not exist!' if not -s File::Spec->join($params{output_path}, "$params{submission_alias}.tar");
print STDERR "Rendering submission XML...done\n";
exit 0;
