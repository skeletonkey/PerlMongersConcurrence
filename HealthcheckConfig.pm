package HealthcheckConfig;

use strict;
use warnings;

sub get_execution_time {
    my $self = shift;

    my @start_time = @{$self->{start_time}};
    my @end_time = localtime();
    return ($end_time[2] - $start_time[2]) * 3600 + ($end_time[1] - $start_time[1]) * 60 + ($end_time[0] - $start_time[0]);
}

sub print_execution_time  {
    my $self = shift;
    my $runtime = $self->get_execution_time();
    print "\nScript Execution time: $runtime seconds\n";
}

sub new { return bless { start_time => [localtime()], }, __PACKAGE__; }

sub healthcheck_col_count    { return $ENV{HEALTHCHECK_COLUMN_COUNT} || 2; }
sub healthcheck_uri_template { return 'http://%s/healthcheck'; }

sub nodes {
    my @lines = `microk8s kubectl describe pod --namespace default | grep IP:`;
    warn(sprintf("Seems that not all nodes are up yet - found: %d, but looking for %d\n", scalar(@lines), node_count() * 2)) unless scalar(@lines) == node_count() * 2;

    my %ips = ();
    foreach my $line (@lines) {
        my ($ip) = $line =~ /IP:\s*(\S+)/;
        next unless $ip;
        $ips{$ip} = 1;
    }

    return keys %ips;
}

sub node_count {
    my @lines = `microk8s kubectl describe deployment mock-healthcheck-deployment | grep replicas`;
    my ($node_count) = $lines[0] =~ /\((\d+)\/\d+ replicas created/;
    $node_count ||= 0;
    die("Seemed that I didn't find a node_count ($node_count) from $lines[0]\n") unless $node_count;
    return $node_count;
}

sub output_file {
    my $self = shift;
    my $name = shift || '';
    return "$ENV{PMP_BASE_DIR}/healthcheck_report/${name}healthcheck.html";
}

sub max_curl_timeout         { return $ENV{CURL_MAX_TIMEOUT} || 10; }
sub tmp_dir                  { return '/tmp';                       }

sub html_top_template {
    return q+
<html>
    <head>
        <title>%s</title>
        <meta http-equiv="refresh" content="5">
        <style>* { font-size: 18px; font-family: Arial; } table, th, td { border: 1px solid #c4c4c4; border-collapse: collapse; } th, td { padding: 2px; text-align: left; } td { font-family: courier; } .warning { background: red; color: white }</style>
    </head>
    <body>
        Last Updated: <span id="report_time"></span>
        <table>
+;
}
sub html_bottom_template {
    return q+
        </table>
        <script>
            var epoch = %s;
            document.getElementById("report_time").innerHTML = new Date(epoch * 1000);
        </script>
    </body>
</html>+;
}
1;