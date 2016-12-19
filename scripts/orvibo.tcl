# Orvibo S20 control

package require udp

# -- Orvibo S20 Control. -------------------------------------------------
proc _orviboSend {id packet} {

   global orvibodb

   set port 10000
   set s [udp_open $port reuse]
   fconfigure $s -remote [list $orvibodb(${id}.ip) $port] -encoding binary
   puts -nonewline $s [binary decode hex $packet]
   close $s
}
   
proc _orviboSubscribe {id} {

   global orvibodb

   set mac $orvibodb(${id}.mac)
   set reverse "[string range $mac 10 11][string range $mac 8 9][string range $mac 6 7][string range $mac 4 5][string range $mac 2 3][string range $mac 0 1]"

   _orviboSend $id "6864001e636c${mac}202020202020${reverse}202020202020"
}

proc orvibo {command id args} {

   global orvibodb

   switch $command {
      declare {
         set orvibodb(${id}.id) $id
         set orvibodb(${id}.mac) [lindex $args 0]
         set orvibodb(${id}.ip) [lindex $args 1]
      }

      off {
         if [info exists orvibodb(${id}.id)] {
            _orviboSubscribe $id
            set packet "686400176463$orvibodb(${id}.mac)2020202020200000000000"
            after 500 "_orviboSend $id $packet"
         }
      }

      on {
         if [info exists orvibodb(${id}.id)] {
            _orviboSubscribe $id
            set packet "686400176463$orvibodb(${id}.mac)2020202020200000000001"
            after 500 "_orviboSend $id $packet"
         }
      }
   }
}

if {[file exists /storage/motion/config/orvibo.tcl]} {
   source /storage/motion/config/orvibo.tcl
}

