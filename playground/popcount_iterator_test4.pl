#!/usr/bin/perl
use strict;
use warnings;

# Again, this comment aside this is the exact code as handed down from GPT-4

my ($k, $n, @previousSet) = @ARGV;

sub next_comb {
    my @set = @_;
    for my $i (reverse 0..$#set) {
        if (++$set[$i] < $n-$#set+$i) {
            @set[$_]=$set[$_ - 1] + 1 for $i+1..$#set;
            return @set;
        }
    }
    return;
}

sub print_set {
    my @set = @_;
    print "[" . join(", ", @set) . "]\n";
}

if (@previousSet) {
    if (@previousSet == $k) {
        my @nextComb = next_comb(@previousSet);
        if (@nextComb) {
            print_set(@nextComb);
        } else {
            print "All combinations have been exhausted.\n";
        }
    }
} else {
    print_set(0..$k-1);
}
