package HealthcheckConfig;

use strict;
use warnings;

my @start_time;
BEGIN { @start_time = localtime(); }
sub print_execution_time  {
    my @end_time = localtime();
    my $runtime = ($end_time[2] - $start_time[2]) * 3600 + ($end_time[1] - $start_time[1]) * 60 + ($end_time[0] - $start_time[0]);
    print "\nScript Execution time: $runtime seconds\n";
}

sub new { return bless {}, __PACKAGE__; }

sub healthcheck_col_count    { return 4;                                                        }
sub healthcheck_uri_template { return 'http://localhost:%d/healthcheck';                        }
sub nodes                    { return 100;                                                      }
sub port_start               { return 5000;                                                     }

sub output_file {
    my $self = shift;
    my $name = shift || '';
    return "$ENV{PMP_BASE_DIR}/healthcheck_report/${name}healthcheck.html";
}

sub max_curl_timeout         { return 10;                                                       }
sub tmp_dir                  { return '/tmp';                                                   }

sub html_top_template {
    return q+
<html>
    <head>
        <title>%s</title>
        <meta http-equiv="refresh" content="65">
        <style>* { font-size: 18px; font-family: Arial; } table, th, td { border: 1px solid #c4c4c4; border-collapse: collapse; } th, td { padding: 2px; text-align: center; } td { font-family: courier; } .warning { background: red; color: white }</style>
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