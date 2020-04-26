#!/usr/bin/perl
use strict;
use warnings;

use JSON::XS;

my $in_service_file = '/var/local/in_service';
 
my $app = sub {
    my $hostname = `hostname`;
    chomp($hostname);
    sleep(int(rand(10)));

    # https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
    # Any code greater than or equal to 200 and less than 400 indicates success. Any other code indicates failure.
    my $response_code = 200;
    my $overall_status = 'Failure';
    my $description = "$in_service_file DOES NOT exists";
    if (-e $in_service_file) {
        $response_code = 200;
        $overall_status = 'Success';
        $description = "$in_service_file exists";
    }
    my %body = (
        overallStatus => $overall_status,
        results => [
            {
                dependency => {
                    name => "Touch File",
                    isCritical => 1,
                    methodology => "Check if file exist (existance of file means server is in rotation)",
                    uri => "file => $in_service_file",
                },
                statusResponse => {
                    statusDescription => $description,
                    status => $overall_status
                }
            },
            {
                dependency => {
                    name => "Database Connection => my_data",
                    isCritical => 1,
                    methodology => "See if able to do a simple select on the database",
                    uri => "DBI:mysql:database=my_data",
                },
                statusResponse => {
                    statusDescription => "OK",
                    status => "Success",
                },
            },
            {
                dependency => {
                    name => "Helper App",
                    isCritical => 1,
                    methodology => "Attempt HTTP connection to URI",
                    uri => "http:://localhost:8080/helper",
                },
                statusResponse => {
                    statusDescription => "OK",
                    status => "Success"
                },
            },
        ],
        hostnameInfo => {
            hostname => $hostname,
        }
    );

    return [
        $response_code,
        [ 'Content-Type' => 'application/json' ],
        [ encode_json(\%body) ],
    ];
};
