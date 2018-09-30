#!/usr/bin/perl -s

use strict;
use warnings;
use vars qw($v);
use lib $ENV{PMP_BASE_DIR};

use Erik qw(log pid disable_header);

use JSON::XS;
use POSIX 'WNOHANG';

use HealthcheckConfig;

use constant SUCCESS => 'Success';

$v ||= 1;

my $config = HealthcheckConfig->new;







my %_children;
my @_child_data;
$SIG{CHLD} = \&reaper_of_children;

sub reaper_of_children {
    while ((my $kid = waitpid(-1, WNOHANG)) > 0) {
        next unless exists $_children{$kid};
        my $fh = $_children{$kid};
        my @lines = <$fh>;
        push(@_child_data, decode_json(join('', @lines)));
        close($fh);
        delete $_children{$kid};
    }
}

foreach my $node (0..$config->nodes) {
    my $port = $node + $config->port_start;

    my $child_pid = open my $fh, "-|";
    if ($child_pid) {
        $_children{$child_pid} = $fh;
    }
    else {
        my ($status, $hostname) = get_healthcheck_data($port);
        my %data = (
            status   => $status,
            hostname => $hostname,
            link     => sprintf($config->healthcheck_uri_template, $port),
            port     => $port,
        );

        print encode_json(\%data);
        exit;
    }
}

while (keys %_children) {
    print 'Children still running (' . join(', ', keys %_children) . ") - waiting\n" if $v;
    sleep(2);
}

open(my $fh, '>', $config->output_file('pipe_')) || die("Unable to open file (" . $config->output_file('pipe_') . ") for write: $!\n");
print $fh build_page(@_child_data);
close($fh);
$config->print_execution_time;










sub get_healthcheck_data {
    my $port    = shift;

    my $healthcheck_uri = sprintf($config->healthcheck_uri_template, $port);
    my $cmd = "curl -s -m " . $config->max_curl_timeout  . " $healthcheck_uri";
    my $response = `$cmd`;

    my $data = decode_json($response);

    return ($data->{overallStatus}, $data->{hostnameInfo}{hostname});
}

sub build_page {
    my @data = @_;
    my $report = sprintf($config->html_top_template, "My Healthcheck Dasboard");

    $report .= '<tr>';
    my $count = 0;
    foreach my $data (sort { $a->{hostname} cmp $b->{hostname}} @data) {
        $report .= "<td" . ( $data->{status} ne SUCCESS ? ' class="warning"' : '' ) . qq+>$data->{status}</td><td><a href="$data->{link}" target="_blank">Pipe: $data->{hostname} ($data->{port})</a></td>+;
        $report .= '</tr><tr>' unless ++$count % $config->healthcheck_col_count;
    }
    $report .= '</tr>';
    $report .= sprintf($config->html_bottom_template, time());

    return $report;
}

