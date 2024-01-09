#!/usr/bin/perl

# == node type legend
# * Dead node (no possible inputs, algo 0)
# -- Update! Later JS revisions will likely dispense with "dead node"
#    as a distinct type, and instead classify "wire/or with no inputs"
#    as a dead node. Also making "wire/or" be the default node type.
#    That way arbitrarily drawing across the field with a mouse
#    will be simpler to support.
# * Input node (no possible inputs, algo input_function(step))
# * Wire/OR (algo Sum>0)
# * NOT/NOR (algo Sum<1)
# * # Star node (algo 1)
# * # AND (algo Sum>1)
# * # XOR (algo Sum==1)
# * # NAND (algo Sum<2)
# * # XNOR (algo Sum!=1)

# == Current status 2023-12-31T20:56-08:00
#
# Things are working quite well!
# Current challenge: Nand has no sense of input vs output
# , so if A and B feed into NAND into O
# , and A is hot while B is cold
# , NAND will feed signal to O but ALSO to B.
# Do I want to enforce input direction somehow?
# Or do I want to change entire network structure to unidirectional somehow?
# Or do I want to introduce a diode node? (ew..)
# Or do I want to brainstorm another clever trick to control output direction?
#

; use Data::Dumper
; use JSON
; use strict
; use warnings
; use POSIX qw(floor)
; use Time::HiRes qw(sleep)

; $SIG{INT} = \&end # Make sure Ctrl-C flows through cleanup

; my $ANSIControlSequenceIntroducer = "\033["
; my $ANSICursorToUpperLeft = "${ANSIControlSequenceIntroducer}H"
; my $ANSIClearScreen = "${ANSICursorToUpperLeft}${ANSIControlSequenceIntroducer}J"
; my $ANSIHideCursor = "${ANSIControlSequenceIntroducer}?25l"
; my $ANSIShowCursor = "${ANSIControlSequenceIntroducer}?25h"
; my $ANSIColorReset = "${ANSIControlSequenceIntroducer}0m"
; my $ANSIDead = "${ANSIColorReset}${ANSIControlSequenceIntroducer}2m"
; my $ANSICold = "${ANSIColorReset}"
; my $ANSIHot  = "${ANSIColorReset}${ANSIControlSequenceIntroducer}1m${ANSIControlSequenceIntroducer}7m"
# ; my $frameDelayInSeconds = 0
; my $frameDelayInSeconds = 0.1
# ; my $frameDelayInSeconds = 0.5
# ; my $frameDelayInSeconds = 0.66
# ; my $frameDelayInSeconds = 1
; my $step = 0
; my $arbitrarilyLargeValue = 9**9**9 # Either "infinity" or close enough for our purposes
; my $Board2D =
  { width => 10
  , height => 10
  , cells =>
    [ qw
      ( 00 00 00 00 00 00 00 00 00 00
        00 00 00 00 00 00 00 00 00 00
        00 00 14 28 18 18 18 18 00 00
        00 00 14 00 00 00 00 00 00 00
        00 00 A0 18 18 18 18 18 00 00
        00 00 11 00 11 00 00 00 00 00
        00 00 11 00 25 18 18 18 00 00
        00 00 11 18 18 00 00 00 00 00
        00 00 00 00 00 00 00 00 00 00
        00 00 00 00 00 00 00 00 00 00
      )
    ]
  }

; my $signalTrainA = [qw(1 1 1 0 0 0 0 0 0)]
; my $inputSignals =
  { 'A' => sub
    { SignalTrain($signalTrainA)->(shift())
    }
  , 'B' => sub
    { my $step = shift
    ; IntMod($step, 4)==0
    }
  }

; sub SignalTrain
  { my $signalTrain = shift
  ; sub
    { !!( $signalTrain->
            [ IntMod
              ( $_[0]
              , scalar(@$signalTrain)
              )
            ]
        )
    }
  }

; my $network = {}
; my $adjecentDirections =
  [ { x =>  0, y => -1 } # Never
  , { x => +1, y =>  0 } # Eat
  , { x =>  0, y => +1 } # Shredded
  , { x => -1, y =>  0 } # Wheat
  ]
# ; my $progressIndicatorSymbols = '-\|/'
# ; my $progressIndicatorSymbols = [qw(- \ | /)]
; my $progressIndicatorSymbols =
  [ qw
    ( >----------
      ->---------
      -->--------
      --->-------
      ---->------
      ----->-----
      ------>----
      ------->---
      -------->--
      --------->-
      ---------->
    )
  ]
; my $cellSymbols =
  { 0 => ' '
  , 1 => '·'
  , 2 => '!'
  , 3 => '#'
  }
; my $inputNeighborBitmaskSymbols = [' ', qw(╵ ╶ └ ╷ │ ┌ ├ ╴ ┘ ─ ┴ ┐ ┤ ┬ ┼)]

; for(my $y=0; $y<$Board2D->{height}; $y++)
  { for(my $x=0; $x<$Board2D->{width}; $x++)
    { my $selfCoordinate = Coordinate2DTorroidTo1D($x, $y, $Board2D)
    ; my $cellSpec = $Board2D->{cells}[$selfCoordinate]
    ; my $nodeType = substr($cellSpec, 0, 1)
    ; my $inputNeighborBitmask = hex(substr($cellSpec, 1, 1))
    ; # prune zero cells from self
    ; if($nodeType eq '0') { next; }
    ; my $self = "main:$selfCoordinate"
    ; my $inputNeighborAddresses = []
    ; foreach my $direction (0..$#$adjecentDirections)
      { # Only include input neighbors indicated by the inputNeighborBitmask
      ; if(!($inputNeighborBitmask & 1<<$direction)) { next; }
      ; my $inputNeighborOffsets = $adjecentDirections->[$direction]
      ; my $inputNeighborCoordinate =
          Coordinate2DTorroidTo1D
          ( $x + $inputNeighborOffsets->{x}
          , $y + $inputNeighborOffsets->{y}
          , $Board2D
          )
      ; # Also prune zero cells from inputNeighbors
      ; if($Board2D->{cells}[$inputNeighborCoordinate] eq '0') { next; }
      ; push(@$inputNeighborAddresses, "main:$inputNeighborCoordinate")
      }
    ; $network->{$self} =
      { nodeType => $nodeType
      , inputNeighborAddresses => $inputNeighborAddresses
      }
    }
  }

# ;die(Dumper($network))
; my $signalMap = {}
; while(1)
  { sleep $frameDelayInSeconds
  ; $signalMap = CalculateSignalMap($network, $signalMap, $step)
  ; DisplayBoard($Board2D, $signalMap, $step)
  ; $step++
  }

; sub Round { floor($_[0]+0.5) }
; sub RealMod { (($_[0]/$_[1]) - floor($_[0]/$_[1]))*$_[1] }
; sub IntMod { Round(RealMod($_[0],$_[1])) }

; sub CalculateSignalMap
  { my $network = shift
  ; my $oldSignalMap = shift // {}
  ; my $newSignalMap = {}
  ; my $step = shift // 0

  ; foreach my $selfAddress (keys %$network)
    { my $nodeType = $network->{$selfAddress}{nodeType}

    ; # prune signals for any possible dead cells that made it into the network
    ; if($nodeType eq '0') { delete($newSignalMap->{$selfAddress}); next; }

    ; # Shortcut star nodes to always hot
    ; if($nodeType eq '3') { $newSignalMap->{$selfAddress} = 1; next; }

    ; # Getting this far means we have a variable cell
    ; my $inputNeighborAddresses = $network->{$selfAddress}{inputNeighborAddresses}
    ; my $sumOfinputNeighbors = 0
    ; foreach my $inputNeighborAddress (@$inputNeighborAddresses)
      { $sumOfinputNeighbors +=
        ( ( defined($oldSignalMap->{$inputNeighborAddress})
          &&$oldSignalMap->{$inputNeighborAddress}>0
          )
        ? 1
        : 0
        )
      }

    ; # Wire/OR nodes gain heat from any inputNeighbors
    ; if($nodeType eq '1')
      { if($sumOfinputNeighbors>0) { $newSignalMap->{$selfAddress} = 1; next; }
        else { delete($newSignalMap->{$selfAddress}); next; }
      }

    ; # NOT/NOR nodes gain heat from all-cold input neighbors
    ; if($nodeType eq '2')
      { if($sumOfinputNeighbors<1) { $newSignalMap->{$selfAddress} = 1; next; }
        else { delete($newSignalMap->{$selfAddress}); next; }
      }

    ; # Input Signal Nodes gain heat only from their input signals
    ; if(defined $inputSignals->{$nodeType})
      { my $inputSignal = $inputSignals->{$nodeType}($step)
# ;CORE::say "($inputSignal)"
      ; if(!!$inputSignal) { $newSignalMap->{$selfAddress} = 1; next; }
        else { delete($newSignalMap->{$selfAddress}); next; }
      }

    ; # Any undefined cells just stay cold.. I guess?
      { delete($newSignalMap->{$selfAddress}); next; }
    }

  ; $newSignalMap
  }

; sub Coordinate2DTorroidTo1D
  { my $x = shift
  ; my $y = shift
  ; my $Board2D = shift
  ; IntMod($x,$Board2D->{width}) + IntMod($y,$Board2D->{height}) * $Board2D->{width}
  }

; sub DisplayBoard
  { my $Board2D = shift
  ; my $signalMap = shift // {}
  ; my $step = shift // 0
  ; my $output = ''

  ; $output .= $ANSIClearScreen
  ; $output .= $ANSIHideCursor
  ; $output .= "$step\n"
  ; $output .=
      $progressIndicatorSymbols->[IntMod($step, scalar(@$progressIndicatorSymbols))]

  ; $output .= "\n\n"
  ; my $color = ''
  ; for(my $y=0; $y<$Board2D->{height}; $y++)
    { for(my $x=0; $x<$Board2D->{width}; $x++)
      { my $coordinate = Coordinate2DTorroidTo1D($x, $y, $Board2D)
      ; my $cellSpec = $Board2D->{cells}[$coordinate]
      ; my $nodeType = substr($cellSpec, 0, 1)
      ; my $inputNeighborBitmask = hex(substr($cellSpec, 1, 1))
      ; my $newColor = ''
      ; if($nodeType eq '0') { $newColor = $ANSIDead; }
#        elsif($nodeType eq '3') { $newColor = $ANSIHot; }
        elsif
        ( defined($signalMap->{"main:$coordinate"})
        &&($signalMap->{"main:$coordinate"}>0)
        ) { $newColor = $ANSIHot; }
        else { $newColor = $ANSICold; }

      ; # deduplicate having to assign ansi color all of the time
      ; if($color ne $newColor)
        { $output .= $newColor
        ; $color = $newColor
        }
      ; if(defined $cellSymbols->{$nodeType})
        { $output .= $cellSymbols->{$nodeType}; }
        else { $output .= $nodeType; }
      ; $output .= $inputNeighborBitmaskSymbols->[$inputNeighborBitmask]
      }
    ; $output .= "\n"
    }
  ; print "${output}${ANSIColorReset}"
  }

; sub acceptInput
  { system("stty -icanon; stty -echo"); # suppress input to screen
  ; binmode(STDIN); # not only confirm binmode, but also flush input stream.
  ; my($select) = IO::Select->new();
  ; $select->add(\*STDIN);
  ; while($select->can_read())
    { sysread(STDIN, my($buf), 1);
    ; if(length($buf))
      {
      }
    }
  }


; sub end
  { CORE::say "${ANSIColorReset}done!${ANSIShowCursor}"
  ; system("stty echo"); # Begin allow echoing input to the screen again
  ; exit
  }
