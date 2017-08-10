#!/usr/bin/env lims-perl

use strict;
use warnings;

use Digest::MD5;
use File::Basename;
use File::Path;
use File::Spec;
use List::Util;
use YAML;

use GSCApp;
my $params = {
    biosample => { doc => 'Biosample for the submission.', },
    bioproject  => { doc => 'Bioproject for the submission.', },
    output_path  => { doc => 'Directory for links, MD5s, and XMLs.', },
    plate_barcodes => { doc => 'Barcode for LIMS containers.', },
    sample  => { doc => 'The LIMS sample to filter on multi sample runs.', },
    skip_md5 => { doc => 'Skip creating the MD5s', type => '!', value => 0, },
    submission_alias  => { doc => 'An alias for the submission.', },
};
App::Getopt->command_line_options(
    (map {
        my $n = $_;
        $n =~ s/_/-/g;
        $n => {
            action => \$params->{$_}->{value},
            argument => ( $params->{$_}->{type} ? $params->{$_}->{type} : '=s' ),
            message => $params->{$_}->{doc},
        },
    } keys %$params),
);
App->init;

my @errors;
for my $param_name ( keys %$params ) {
    next if exists $params->{$param_name}->{type} and $params->{$param_name}->{type} eq '!';
    push @errors, "No $param_name given!" if not $params->{$param_name}->{value};
}
die join("\n", @errors) if @errors;
print STDERR "Params: \n".join("\n", map { sprintf('%17s => %s', $_, $params->{$_}->{value}) } sort keys %$params)."\n";

my @plate_barcodes = split(/[,\s+]/, $params->{plate_barcodes}->{value});
my @pacbio_runs = GSC::Equipment::PacBio::Run->get(plate_barcode => \@plate_barcodes);
die sprintf('No PacBio runs for plate barcodes! %s', join(' ', @plate_barcodes)) if not @pacbio_runs;
die sprintf('Did not find all PacBio runs for plate barcodes! %s', join("\n", map { YAML::Dump } @pacbio_runs)) if @pacbio_runs != @plate_barcodes;
printf STDERR "PacBio run ids: %s\n", join(' ', map { $_->id } @pacbio_runs);

my $sample = GSC::Organism::Sample->get(
    $params->{sample}->{value} =~ /^\d+$/
    ? ( id => $params->{sample}->{value} )
    : ( full_name => $params->{sample}->{value} )
);
die sprintf('No sample for %s', $params->{sample}->{value}) if not $sample;

File::Path::make_path($params->{output_path}->{value}) if not -d $params->{output_path}->{value};
die sprintf('Output path does not exist! %s', $params->{output_path}->{value}) if not -d $params->{output_path}->{value};

print STDERR "Gathering run files...\n";
my @files;
for my $pacbio_run ( @pacbio_runs ) {
    for my $file ( $pacbio_run->get_primary_analysis_data_files ) {
        die "File does not exist! $file" if not -s $file;
        push @files, $file;
    }
}
my $max = List::Util::max( map { -s $_ } @files);
printf STDERR ("Largest file [Kb]: %.0d\n", ($max/1024));

print STDERR "Linking files...\n";
for my $file ( @files ) {
    my $link = File::Spec->join($params->{output_path}->{value}, File::Basename::basename($file));
    symlink($file, $link)
        or die sprintf('ERROR: %s. Failed to link %s to %s.', ( $! || 'NA' ), $file, $link);
}
print STDERR "Linking files...done\n";

print STDERR "Generating MD5s...\n";
my $digester = Digest::MD5->new;
for my $file ( @files ) {
    my $fh = IO::File->new($file)
        or die "Failed to open $file => $!";
    $fh->binmode;
    $digester->addfile($fh);
    my $md5_file = File::Spec->join($params->{output_path}->{value}, File::Basename::basename($file).'.md5');
    my $md5_fh = IO::File->new($md5_file, 'w')
        or die "Failed to open $md5_file => $!";
    $md5_fh->print($digester->hexdigest."\n");
    $md5_fh->close;
}
print STDERR "Running MD5 on files...done\n";

print STDERR "Rendering submission XML...\n";
my $rv = GSC::Equipment::PacBio::Run->render_submission_xml(
    barcodes => \@plate_barcodes,
    organism_sample => $sample,
    bioproject_id => $params->{bioproject}->{value},
    biosample_id => $params->{biosample}->{value},
    submission_alias => $params->{submission_alias}->{value},
    write_tar_file_to_dir => $params->{output_path}->{value},
    );
die 'Failed to create submission XML!' if not $rv;
die 'Rendered submssion XML, but submission tar file does not exist!' if not -s File::Spec->join($params->{output_path}->{value}, $params->{submission_alias}->{value}.".tar");
print STDERR "Rendering submission XML...done\n";
exit 0;
