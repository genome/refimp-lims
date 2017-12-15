package PacBio;

use strict;
use warnings 'FATAL';

use PacBio::Run::Submit;
use PacBio::Run::Verify;
use PacBio::Run::View;

use List::MoreUtils 'any';

use GSCApp;

sub run {
    my $pacbio_usage = "Valid 'pacbio' sub-commands:\n  run";
    my $run_usage = "Valid 'pacbio run' sub-commands:
    submit	gather runs and info, generate XML and send to SRA
    verify	verify barcode samples and analysis files
    view		show run info via barcodes";
    my $help_regexp = qr/^\-{1,2}h(elp)?$/;

    my $cmd1 = shift @ARGV;
    my $cmd2 = shift @ARGV;

    if ( ! $cmd1 or $cmd1 =~ $help_regexp ) {
        print "$pacbio_usage\n";
        exit 0;
    }
    if ( $cmd1 ne 'run' ) {
        print "Invalid sub-command for pacbio: $cmd1\n$run_usage\n";
        exit 1;
    }

    if ( ! $cmd2 or $cmd2 =~ $help_regexp ) {
        print "$run_usage\n";
	    exit 0;
    }
    if ( ! any { $cmd2 eq $_ } (qw/ submit verify view /)) {
	    print "Invalid sub-command for pacbio run: $cmd2\n$run_usage\n";
	    exit 1;
    }

    my $cmd_class = join('::', 'PacBio', join('', map { ucfirst } split(/\-/, $cmd1)), join('', map { ucfirst } split(/\-/, $cmd2)));
    if ( ! $cmd_class->can('help') ) {
	    print "Invalid sub-command for pacbio run: $cmd2\n$run_usage";
	    exit 1;
    }

    my $clo = $cmd_class->command_line_options;
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
    my $cmd = $cmd_class->new(%params);
    $cmd->execute;
    0;
}

1;
