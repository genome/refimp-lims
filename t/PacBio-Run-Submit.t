#!/usr/bin/env lims-perl

use strict;
use warnings 'FATAL';

use Test::More tests => 1;
use PacBioTestEnv;

my $pkg = 'PacBio::Run::Submit';
use_ok($pkg) or die;

done_testing();
