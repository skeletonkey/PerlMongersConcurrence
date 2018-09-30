#!/usr/bin/perl

use strict;
use warnings;

use Statistics::Basic qw(:all);
use Erik qw(off);

my @maxes = ( 200, 100, 80, 60, 40, 20, 15, 10, 5, 2);
my $runs = 20;

my %data;
foreach my $max (@maxes) {
    for (my $i = 0; $i < $runs; $i++) {
        print "Checking $max: ";
        my $ret = `./healthcheck_concurrent.pl -m=$max`;
        my ($seconds) = $ret =~ /Script Execution time: (\d+) seconds/ms;
        print "$seconds\n";
        push(@{$data{$max}}, $seconds);
    }
}


foreach my $max (@maxes) {
    Erik::dump(data => $data{$max});
    print "Stats for Max Children: $max\n";
    my $mean = mean($data{$max});
    Erik::log("mean: $mean");
    my $v = $mean->query_vector;
    print "\tAverage: $mean\n";
    printf "\tMedian: %s\n", median($v);
    printf "\tStandard Deviation: %s\n", stddev($v);
    printf "\tVariance: %s\n", variance($v);
}

foreach my $max (@maxes) {
    print "$max," . join(',', @{$data{$max}}) . "\n";
}

