#!/usr/bin/perl -s

use strict;
use warnings;
use vars qw($v $m);
use lib $ENV{PMP_BASE_DIR};

use Erik;

use JSON::XS;

use Jundy::Concurrent;
use HealthcheckConfig;

use constant SUCCESS => 'Success';

$v ||= 0;
$m ||= 10;








my $config = HealthcheckConfig->new;
my $concurrent = Jundy::Concurrent->new(unmarshall => \&decode_json, verbose => $v, max_children => $m);

foreach my $node (0..$config->nodes) {
    my $port = $node + $config->port_start;

    $concurrent->register(\&child_process, $port);
}
$concurrent->wait;

open(my $fh, '>', $config->output_file('cc_')) || die("Unable to open file (" . $config->output_file('cc_') . ") for write: $!\n");
print $fh build_page($concurrent->get_data);
close($fh);
$config->print_execution_time;







sub child_process {
    my $port = shift;
    my ($status, $hostname) = get_healthcheck_data($port);
    my %data = (
        status   => $status,
        hostname => $hostname,
        link     => sprintf($config->healthcheck_uri_template, $port),
        port     => $port,
    );

    print encode_json(\%data);
}

sub get_healthcheck_data {
    my $port    = shift;

    my $healthcheck_uri = sprintf($config->healthcheck_uri_template, $port);
    my $cmd = "curl -s -m " . $config->max_curl_timeout  . " $healthcheck_uri";
    my $response = `$cmd`;

    my $data;
    eval {
        $data = decode_json($response);
    } || do {
        Erik::log("Error on trying to decode response form $port");
        Erik::log("response => $response");
        $data = {
            overallStatus => 'Failure',
            hostnameInfo  => { hostname => "Port $port" }
        };
    };

    return ($data->{overallStatus}, $data->{hostnameInfo}{hostname});
}

sub build_page {
    my $child_data = shift;
    my $report = sprintf($config->html_top_template, "My Healthcheck Dasboard");

    $report .= '<tr>';
    my $count = 0;
    foreach my $data (sort { $a->{hostname} cmp $b->{hostname}} @$child_data) {
        $report .= "<td" . ( $data->{status} ne SUCCESS ? ' class="warning"' : '' ) . qq+>$data->{status}</td><td><a href="$data->{link}" target="_blank">CC: $data->{hostname} ($data->{port})</a></td>+;
        $report .= '</tr><tr>' unless ++$count % $config->healthcheck_col_count;
    }
    $report .= '</tr>';
    $report .= sprintf($config->html_bottom_template, time());

    return $report;
}

