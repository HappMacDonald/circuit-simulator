#!/usr/bin/perl
; use strict
; use warnings
; use Data::Dumper

; my ($k, $n, @previousSet) = @ARGV

; sub next_comb
  { my @set = @_;
  ; for my $i (reverse 0..$#set)
    { if (++$set[$i] < $n-$#set+$i)
      { @set[$_]=$set[$_ - 1] + 1 for $i+1..$#set
      ; return @set;
      }
    }
  ; return
  }

; if (@previousSet)
  { if (@previousSet == $k)
    { my @nextComb = next_comb(@previousSet)
    ; if (@nextComb)
      { CORE::say Dumper(@nextComb)
      }
      else
      { print "All combinations have been exhausted.\n"
      }
    }
  }
  else
  { CORE::say Dumper(0..$k-1)
  }
