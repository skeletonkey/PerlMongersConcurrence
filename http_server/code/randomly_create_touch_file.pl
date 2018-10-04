#!/usr/bin/perl

use strict;
use warnings;

my $touch_file = '/var/local/in_service';

my $in_service_percent = 80;

my $rand = int(rand(100));

if ($rand <= $in_service_percent) {
    system("touch $touch_file") unless -e $touch_file;
}
else {
    unlink($touch_file) if -e $touch_file;
}
