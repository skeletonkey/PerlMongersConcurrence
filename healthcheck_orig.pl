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

$v ||= 0;

my $config = HealthcheckConfig->new;





my %_children;
$SIG{CHLD} = \&reaper_of_children;

sub reaper_of_children {
    while ((my $kid = waitpid(-1, WNOHANG)) > 0) {
        delete $_children{$kid};
    }
}

foreach my $node (0..$config->nodes) {
    my $port = $node + $config->port_start;

    die("Unable to fork") unless defined (my $child_pid = fork);
    if ($child_pid) {
        $_children{$child_pid}++;
    }
    else {
        my ($status, $hostname) = get_healthcheck_data($port);
        my %data = (
            status   => $status,
            hostname => $hostname,
            link     => sprintf($config->healthcheck_uri_template, $port),
            port     => $port,
        );

        my $file_name = get_temp_file($node);
        open(my $fh, '>', $file_name) || die("Unable to open file ($file_name) from write: $!\n");
        print $fh encode_json(\%data);
        close($fh);
        exit;
    }
}

while (keys %_children) {
    print 'Children still running (' . join(', ', keys %_children) . ") - waiting\n" if $v;
    sleep(2);
}

open(my $fh, '>', $config->output_file('fork_')) || die("Unable to open file (" . $config->output_file('fork') . ") for write: $!\n");
print $fh build_page();
close($fh);
$config->print_execution_time;














sub get_snippets {
    my @files = ();
    foreach my $node (0..$config->nodes) {
        push(@files, get_temp_file($node));
    }
    return @files;
}
sub get_temp_file {
    my $node = shift;
    return $config->tmp_dir . '/' . $$ . '_' . $node . '.part';
}

sub get_healthcheck_data {
    my $port    = shift;
    print "Getting Healthcheck for port: $port\n" if $v;

    my $healthcheck_uri = sprintf($config->healthcheck_uri_template, $port);
    my $cmd = "curl -s -m " . $config->max_curl_timeout  . " $healthcheck_uri";
    my $response = `$cmd`;

    my $data = decode_json($response);

    return ($data->{overallStatus}, $data->{hostnameInfo}{hostname});
}

sub build_page {
    my $report = sprintf($config->html_top_template, "My Healthcheck Dasboard");

    $report .= '<tr>';
    my $count = 0;
    my @data;
    foreach my $file (get_snippets()) {
        open(my $fh, '<', $file) || die("Unable to open file ($file) for read: $!\n");
        my @lines = <$fh>;
        close($fh);
        unlink($file);
        push(@data, decode_json(join('', @lines)));
    }
    foreach my $data (sort {$a->{hostname} cmp $b->{hostname}} @data) {
        $report .= "<td" . ( $data->{status} ne SUCCESS ? ' class="warning"' : '' ) . qq+>$data->{status}</td><td><a href="$data->{link}" target="_blank">Original: $data->{hostname} ($data->{port})</a></td>+;
        $report .= '</tr><tr>' unless ++$count % $config->healthcheck_col_count;
    }
    $report .= '</tr>';
    $report .= sprintf($config->html_bottom_template, time());

    return $report;
}

