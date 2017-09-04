# Orvibo S20 control

package require udp

# -- Orvibo S20 Web User Interface. --------------------------------------

Direct_Url /api/plug webApiPlug

proc _orviboList {} {

   global orvibodb

   set sep "\["

   foreach id [lsort [array names orvibodb *.id]] {
      set id $orvibodb(${id})
      append result "${sep}{\"name\":\"$id\"}"
      set sep ","
   }
   append result "\]"

   return $result
}

proc webApiPlug/list {} {
   _orviboList
}

proc webApiPlug/set {name state} {
   orvibo $state $name
}

proc webApiPlug/declare {name mac} {
   orvibo declare $name $mac

   global orviboConfigDir
   set fd [open [file join $orviboConfigDir orvibo-live.tcl] a]
   puts $fd "orvibo declare $name $mac"
   close $fd

   _orviboList
}


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
         if {[llength $args] >= 2} {
            set orvibodb(${id}.ip) [lindex $args 1]
         } else {
            set orvibodb(${id}.ip) $id
         }
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

