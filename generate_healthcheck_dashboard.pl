#!/usr/bin/perl -s

use lib $ENV{PMP_BASE_DIR};

use strict;
use warnings;
use vars qw($v $m);

use Erik qw(log);

use JSON::XS;

use Jundy::Concurrent;
use HealthcheckConfig;

use constant SUCCESS => 'Success';

$v ||= 0;
$m ||= 50;

my $sleep_duration = 30;

my $run_touch_file = $ENV{PMP_BASE_DIR} . '/.run_healthcheck_concurrent';







do {
    my $config = HealthcheckConfig->new;
    my $concurrent = Jundy::Concurrent->new(
        clear_data_on_get => 1,
        max_children      => $m,
        unmarshall        => \&decode_json,
        verbose           => $v,
    );

    foreach my $ip ($config->nodes) {
        $concurrent->register(\&child_process, $config->healthcheck_uri_template(), $ip, $config->max_curl_timeout());
    }
    $concurrent->wait;

    open(my $fh, '>', $config->output_file('cc_')) || die("Unable to open file (" . $config->output_file('cc_') . ") for write: $!\n");
    print $fh build_page($config, $concurrent->get_data);
    close($fh);
    $config->print_execution_time;
    if ($config->get_execution_time() < 5) {
        print "Execution way to fast - sleeping $sleep_duration seconds\n";
        sleep($sleep_duration);
    }
} while (-e $run_touch_file);







sub child_process {
    my $healthcheck_uri_template = shift;
    my $ip = shift;
    my $timeout = shift || 10;

    my ($status, $hostname) = get_healthcheck_data($healthcheck_uri_template, $ip, $timeout);
    my %data = (
        status   => $status,
        hostname => $hostname,
        ip       => $ip,
        link     => sprintf($healthcheck_uri_template, $ip),
        port     => 80,
    );

    print encode_json(\%data);
}

sub get_healthcheck_data {
    my $healthcheck_uri_template = shift;
    my $ip = shift;
    my $max_curl_timeout = shift || 10;

    my $healthcheck_uri = sprintf($healthcheck_uri_template, $ip);
    my $cmd = "curl -s -m " . $max_curl_timeout  . " $healthcheck_uri";
    my $response = `$cmd`;

    my $data;
    eval {
        $data = decode_json($response);
    } || do {
        Erik::log("Error on trying to decode response form $ip");
        Erik::log("Error detected: $@");
        Erik::log("response => $response");
        $data = {
            overallStatus => 'Failure',
            hostnameInfo  => { hostname => "Port $ip" }
        };
    };
    $data->{hostnameInfo}{hostname} =~ s/^mock-healthcheck-deployment-55f44ccd79-//;

    return ($data->{overallStatus}, $data->{hostnameInfo}{hostname});
}

sub build_page {
    my $config = shift;
    my $child_data = shift;

    my $report = sprintf($config->html_top_template, "My Healthcheck Dasboard");

    $report .= '<tr>';
    my $count = 0;
    # foreach my $data (sort { $a->{ip} cmp $b->{ip}} @$child_data) {
    foreach my $data (sort sort_by_ip @$child_data) {
        $report .= "<td" . ( $data->{status} ne SUCCESS ? ' class="warning"' : '' ) . qq+>$data->{status}</td><td><a href="$data->{link}" target="_blank">$data->{ip} - $data->{hostname}</a></td>+;
        $report .= '</tr><tr>' unless ++$count % $config->healthcheck_col_count;
    }
    $report .= '</tr>';
    $report .= sprintf($config->html_bottom_template, time());

    return $report;
}

sub sort_by_ip {
    my @a = split(/\./, $a->{ip});
    my @b = split(/\./, $b->{ip});

    my $ret = 0;
    IP_LOOP: for (my $i = 0; $i < @a; $i++) {
        if ($a[$i] > $b[$i]) {
            $ret = 1;
            last IP_LOOP;
        }
        elsif ($a[$i] < $b[$i]) {
            $ret = -1;
            last IP_LOOP;
        }
    }

    return $ret;
}
