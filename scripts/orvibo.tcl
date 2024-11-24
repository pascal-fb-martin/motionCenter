# Orvibo S20 control

# Declare this driver, so that the plug Web interface can call it.
#
lappend PlugDrivers orvibo

# Orvibo S20 Network Protocol. -------------------------------------------

package require udp

set orvibonet [udp_open 10000 reuse]
fconfigure $orvibonet -broadcast 1 -buffering none -encoding binary

proc _orviboUpdate {mac ip state} {
   global orvibodb orvibonew
   if {[info exists orvibodb(${mac}.macindex)]} {
      set id $orvibodb(${mac}.macindex)
      set orvibodb(${id}.ip) $ip
      set orvibodb(${id}.state) [string match 01 $state]
      set orvibodb(${id}.timestamp) [clock seconds]
   } else {
      set orvibonew(${mac}.mac) $mac
      set orvibonew(${mac}.ip) $ip
      set orvibonew(${mac}.timestamp) [clock seconds]
   }
}

proc _orviboRetire {delay} {

   global orvibodb orvibonew

   set retirenow [expr [clock seconds] - $delay]

   foreach id [array names orvibodb *.id] {
      set id $orvibodb(${id})
      if {$orvibodb(${id}.timestamp) < $retirenow} {
         set orvibodb(${id}.ip) {}
      }
   }

   foreach mac [array names orvibonew *.mac] {
      set mac $orvibonew($mac)
      if {$orvibonew(${mac}.timestamp) < $retirenow} {
         unset orvibonew(${mac}.mac)
         unset orvibonew(${mac}.ip)
         unset orvibonew(${mac}.timestamp)
      }
   }
}

proc _orviboReceive socket {
   set data [binary encode hex [read $socket]]
   set peer [udp_conf $socket -peer]

   # If the message is a discovery or command response,
   # update its IP address and state.

   if {[string match -nocase 6864002A716100* $data]} {
      set mac [string toupper [string range $data 14 25]]
      set state [string range $data 82 83]
      _orviboUpdate $mac [lindex $peer 0] $state
   }

   if {[string match -nocase 6864001773* $data]} {
      set mac [string toupper [string range $data 12 23]]
      set state [string range $data 44 45]
      _orviboUpdate $mac [lindex $peer 0] $state
   }
}

fileevent $orvibonet readable [list _orviboReceive $orvibonet]

proc _orviboSense socket {
   fconfigure $socket -remote [list 255.255.255.255 10000]
   puts -nonewline $socket [binary decode hex 686400067161]
}

proc _orviboRefresh socket {
   _orviboSense $socket
   _orviboRetire 180
   after 60000 _orviboRefresh $socket
}

proc _orviboSend {id packet} {

   global orvibodb orvibonet

   fconfigure $orvibonet -remote [list $orvibodb(${id}.ip) 10000]
   puts -nonewline $orvibonet [binary decode hex $packet]
}
   
proc _orviboSubscribe {id} {

   global orvibodb

   set mac $orvibodb(${id}.mac)
   set reverse "[string range $mac 10 11][string range $mac 8 9][string range $mac 6 7][string range $mac 4 5][string range $mac 2 3][string range $mac 0 1]"

   _orviboSend $id "6864001e636c${mac}202020202020${reverse}202020202020"
}

# Orvibo Driver Interface. ------------------------------------------------
#
proc orvibo {command {id {}} args} {

   global PlugDevices orvibodb

   switch $command {
      declare {
         set orvibodb(${id}.id) $id
         set mac [lindex $args 0]
         set orvibodb(${id}.mac) $mac
         set orvibodb(${mac}.macindex) $id
         if {[llength $args] >= 2} {
            set orvibodb(${id}.ip) [lindex $args 1]
         } else {
            set orvibodb(${id}.ip) {}
         }
         set orvibodb(${id}.timestamp) [clock seconds]

         global orvibonew
         if {[info exists orvibonew(${mac}.mac)]} {
            unset orvibonew(${mac}.mac)
            unset orvibonew(${mac}.ip)
         }

         # Force an immediate discovery of this new plug.
         global orvibonet
         _orviboSense $orvibonet

	 # Declare this device to the plug interface.
	 set PlugDevices($id) orvibo
      }

      add {
         set mac [lindex $args 0]
         orvibo declare $id $mac
	 global orviboConfigDir
         set fd [open [file join $orviboConfigDir orvibo-live.tcl] a]
	 puts $fd "orvibo declare $id $mac"
         close $fd
      }

      detected {
         global orvibonew
	 set result {}
         foreach id [lsort [array names orvibonew *.mac]] {
            set mac $orvibonew($id)
            set ip $orvibonew(${mac}.ip)
            lappend result "{\"driver\":\"orvibo\",\"mac\":\"$mac\",\"ip\":\"$ip\"}"
         }
         return $result
      }

      known {

         set result {}

         foreach id [lsort [array names orvibodb *.id]] {
            set id $orvibodb(${id})
            set ip $orvibodb(${id}.ip)
            if {$ip != {}} {
               set s $orvibodb(${id}.state)
               lappend result "{\"name\":\"$id\",\"ip\":\"$ip\",\"state\":$s,\"driver\":\"orvibo\"}"
            } else {
               lappend result "{\"name\":\"$id\",\"driver\":\"orvibo\"}"
            }
         }
         return $result
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

      dim {
         # Not supported.
      }
   }
}


# Load the local configuration.
#
if {[cget motionCenter] == {}} {
   # Vanilla TclHttpd config file: assume fixed location.
   #
   set orviboConfigDir /storage/motion/config
} else {
   # Customized TclHttpd config file: use the configuration.
   #
   set orviboConfigDir [file join [cget motionCenter] config]
}
foreach cf [list orvibo.rc orvibo.tcl orvibo-live.tcl] {
   set cfp [file join $orviboConfigDir $cf]
   if {[file readable $cfp]} {
      source $cfp
   }
}

_orviboRefresh $orvibonet

