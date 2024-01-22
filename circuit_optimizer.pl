#!/usr/bin/perl

; use 5.10.0
; use strict
; use warnings
; use JSON
; use Data::Dumper
; use POSIX qw(floor round)
; use List::Util qw(min max)
; use constant
  { EPSILON => 1e-6
  }

; my $inputPropositions =
  [ '0000000011111111'
  , '0000111100001111'
  , '0011001100110011'
  , '0101010101010101'
  ]

; my $requiredOutputProposition = '1011011111101011'

; my $allowableGates =
  { 'OR'   => { table => '0111' }
  , '3OR'  => { table => '01111111' }
  , 'NOR'  => { table => '1000' }
  , '3NOR' => { table => '10000000' }
  }

; my $allowableGatesOrder = [qw(OR 3OR NOR 3NOR)]

; for my $inputPropositionIndex (0..$#$inputPropositions)
  { die
    ( 'Error: input proposition #'
    . $inputPropositionIndex
    . ' == '
    . $inputPropositions->[$inputPropositionIndex]
    . ' fails to be the same length as required output proposition '
    . $requiredOutputProposition
    )
      unless
      ( length($inputPropositions->[$inputPropositionIndex])
      ==length($requiredOutputProposition)
      )
  }

; for my $gateName (@$allowableGatesOrder)
  { $allowableGates->{$gateName}{inputSize} =
      GateInputSize($allowableGates->{$gateName}{table})
  }

; my $orderedPropositions = [@$inputPropositions] # shallow clone
; my $hashedPropositions = {}
; for my $inputPropositionIndex (0..$#$inputPropositions)
  { $hashedPropositions->{$inputPropositions->[$inputPropositionIndex]} =
      { originalInput => $inputPropositionIndex }
  }

; my $currentPropositionBatchLength

; SEARCH: while(1) # emulating do..while()
  { $currentPropositionBatchLength = @$orderedPropositions
  ; for my $gateName (@$allowableGatesOrder)
    { my $inputSize = $allowableGates->{$gateName}->{inputSize}
    ; my $inputPropositionIndices
    ; while
      ( $inputPropositionIndices =
          NchooseKiterator
          ( $inputSize
          , $currentPropositionBatchLength
          , $inputPropositionIndices
          )
      )
      { my $newProposition =
          UseGate
          ( $gateName
          , @$orderedPropositions[@$inputPropositionIndices]
          )
      ; if(!$hashedPropositions->{$newProposition})
        { push @$orderedPropositions, $newProposition
        ; $hashedPropositions->{$newProposition} =
            { gateName => $gateName
            , inputPropositionIndices => [@$inputPropositionIndices]
            }
# ;if
# ( $gateName eq '3NOR'
# &&join(',',@$inputPropositionIndices) eq '2,17,19'
# )
# { foreach my $i (@$inputPropositionIndices)
#   { CORE::say "$i\t$orderedPropositions->[$i]"
#   }
#   ;CORE::say "\t$gateName ="
#   ;CORE::say "\t$newProposition"
#   ;CORE::say "$newProposition =>"
#   ;CORE::say Dumper($hashedPropositions->{$newProposition})
#   ;<>
# }

        ; if($newProposition eq $requiredOutputProposition)
          { last SEARCH
          }
# ;CORE::say "orderedPropositions: ". scalar(@$orderedPropositions)
        } # else do nothing, just skip this iteration.
      }
    }
# ;CORE::say "currentPropositionBatchLength: $currentPropositionBatchLength"
# ;CORE::say "orderedPropositions: ". scalar(@$orderedPropositions)
  ; last unless($currentPropositionBatchLength<scalar(@$orderedPropositions))
  }

;CORE::say
  encode_json
  ( { orderedPropositions => $orderedPropositions
    , hashedPropositions => $hashedPropositions
    }
  )

; sub NchooseKiterator
  { my $k = shift
  ; my $n = shift
  ; my $previousCombination = shift
  ; return [0..$k-1]
      if
      ( !defined($previousCombination)
      ||ref($previousCombination) ne 'ARRAY'
      ||!@$previousCombination
      )

  ; # Cannot shallow-copy this input for safety until
  ; # after we've proven that it is a valid array reference
  ; $previousCombination = [@$previousCombination]
  ; for my $previousCombinationIndex (reverse 0..$#$previousCombination)
    { if
      ( ++$previousCombination->[$previousCombinationIndex]
      < ( $n - $#$previousCombination + $previousCombinationIndex )
      )
      { @$previousCombination[$_]=$previousCombination->[$_ - 1] + 1
          for $previousCombinationIndex+1..$#$previousCombination
      ; return [@{$previousCombination}];
      }
    }
  ; return undef
  }

; sub GateInputSize
  { my $gate = shift
  ; my $length = length($gate)
  ; die("Error: Failed call to GateInputSize on empty bitstring")
      unless($length>0)
  ; my $bits = log($length)/log(2)
  ; die("Error: Failed call to GateInputSize on bitstring $length bits long (not a power of 2)")
      unless(abs($bits - round($bits))<EPSILON)
  ; round($bits)
  }

; sub UseGate
  { my $gateName = shift
  ; my $inputPropositions = [@_]
  ; my $gateData = $allowableGates->{$gateName}
  ; die
    ( 'Error: Called UseGate with '
    . @$inputPropositions
    . ' inputs on gate $gateName which requires exactly '
    . $gateData->{inputSize}
    . ' inputs'
    ) unless(@$inputPropositions == $gateData->{inputSize})
  ; my $inputLength = length($requiredOutputProposition)
  ; # We're going to trust that it's impossible to have an input bitstring
  ; # that's a different length by this point
  ; my $newProposition = ''
  ; for my $bitIndex (0..($inputLength-1))
    { my $inputs = 0
    ; for my $inputPropositionIndex (0..$#$inputPropositions)
      { $inputs *= 2
      ; $inputs +=
          substr($inputPropositions->[$inputPropositionIndex], $bitIndex, 1)
      }
      $newProposition .= substr($gateData->{table}, $inputs, 1)
    }
  ; $newProposition
  }
