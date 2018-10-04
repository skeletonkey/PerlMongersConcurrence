#!/usr/bin/perl

use strict;
use warnings;
use lib $ENV{PMP_BASE_DIR};

use HealthcheckConfig;

my $config = HealthcheckConfig->new();
my $name = 'healthcheck_at_';

my $mode = $ARGV[0] || 'start';

if ($mode eq 'start') {
    foreach my $i (0..$config->nodes) {
        my $port = $config->port_start + $i;
        system("docker run -d --rm --name $name$port -p $port:5000  -v $ENV{PMP_BASE_DIR}/http_server/code:/code http_server");
    }
}
elsif ($mode eq 'stop') {
    my $cmd = 'docker stop ';
    foreach my $i (0..$config->nodes) {
        my $port = $config->port_start + $i;
        $cmd .= " $name$port";
    }
    system($cmd);
}
else {
    print "Unknown mode ($mode): start|stop\n";
}

