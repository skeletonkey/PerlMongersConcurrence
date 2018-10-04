#!/usr/bin/perl -s

use strict;
use warnings;
use vars qw($v);
use lib $ENV{PMP_BASE_DIR};
use Erik;

use JSON::XS;

use HealthcheckConfig;

use constant SUCCESS => 'Success';

$v ||= 0;

my $config = HealthcheckConfig->new;








my @all_data;
foreach my $node (0..$config->nodes) {
    my $port = $node + $config->port_start;

    my ($status, $hostname) = get_healthcheck_data($port);
    push(@all_data, {
        status   => $status,
        hostname => $hostname,
        link     => sprintf($config->healthcheck_uri_template, $port),
        port     => $port,
    });
}

open(my $fh, '>', $config->output_file('First')) || die("Unable to open file (" . $config->output_file('synch') . ") for write: $!\n");
print $fh build_page(@all_data);
close($fh);
$config->print_execution_time;















sub get_healthcheck_data {
    my $port    = shift;
    print "Getting Healthcheck for port: $port\n" if $v;

    my $healthcheck_uri = sprintf($config->healthcheck_uri_template, $port);
    my $cmd = "curl -s -m " . $config->max_curl_timeout  . " $healthcheck_uri";
    my $response = `$cmd`;

    my $data;
    eval {
        $data = decode_json($response);
    } || do {
        Erik::log("unable to decode_json data from $port");
        Erik::log("Error: $@");
        Erik::log("response: $response");
        $data = {
            overallStatus => 'Failure',
            hostnameInfo  => { hostname => "Port: $port" }
        };
    };

    return ($data->{overallStatus}, $data->{hostnameInfo}{hostname});
}

sub build_page {
    my @data = @_;
    my $report = sprintf($config->html_top_template, "My Healthcheck Dasboard");

    $report .= '<tr>';
    my $count = 0;
    foreach my $data (sort {$a->{hostname} cmp $b->{hostname}} @data) {
        $report .= "<td" . ( $data->{status} ne SUCCESS ? ' class="warning"' : '' ) . qq+>$data->{status}</td><td><a href="$data->{link}" target="_blank">Original: $data->{hostname} ($data->{port})</a></td>+;
        $report .= '</tr><tr>' unless ++$count % $config->healthcheck_col_count;
    }
    $report .= '</tr>';
    $report .= sprintf($config->html_bottom_template, time());

    return $report;
}
