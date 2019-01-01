# This is a very simple scheduler: schedule Tcl commands at predefined
# times of day, with an optional randomized variance and the ability
# to specify some days of the week.

# -- Schedule Web User Interface. ----------------------------------------

Direct_Url /api/schedule webApiSchedule

proc webApiSchedule/list {} {

   global scheduledb

   set sep "\["

   foreach id [lsort [array name scheduledb sch.*.id]] {
      set id $scheduledb($id)
      set c $scheduledb($id.device)
      set d $scheduledb($id.days)
      set s $scheduledb($id.start)
      set e $scheduledb($id.end)
      set r $scheduledb($id.random)
      append result "${sep}{\"id\":\"$id\",\"days\":\"$d\",\"start\":\"$s\",\"end\":\"$e\",\"random\":$r,\"dev\":\"$c\"}"
      set sep ","
   }
   append result "\]"

   return $result
}

proc webApiSchedule/devices {} {

   global scheduledb

   set sep "\["

   foreach id [lsort [array name scheduledb dev.*.id]] {
      set id $scheduledb($id)
      set n $scheduledb($id.on)
      set f $scheduledb($id.off)
      append result "${sep}{\"id\":\"$id\",\"on\":\"$n\",\"off\":\"$f\"}"
      set sep ","
   }
   append result "\]"

   return $result
}

proc webApiSchedule/state {} {

   global scheduleIsActive
   return "{\"active\":$scheduleIsActive}"
}

proc webApiSchedule/enable {} {

   global scheduleIsActive
   eventlog "enable scheduling of automation commands"
   set scheduleIsActive 1
}

proc webApiSchedule/disable {} {

   global scheduleIsActive scheduledb
   eventlog "disable scheduling of automation commands"
   set scheduleIsActive 0

   foreach dev [array names scheduledb dev.*.id] {
      set dev $scheduledb($dev)
      set command $scheduledb($id.off)
      eventlog "executing $command"

      if {[catch [eval $command] msg]} {
         eventlog "failed $command ($msg)"
      }
   }
}

# -- Schedule Configuration and Execution. -------------------------------

set scheduleid 0
set scheduleIsActive 1

proc eventlogwrite {text} {
   set f [open /var/lib/motion/schedulelog.txt a]
   puts $f "[clock format [clock seconds]]: $text"
   close $f
}

proc eventlog {text} {
   catch {eventlogwrite $text}
}

proc _convertTimeOfDay {timeofday} {
   if {$timeofday == {}} return {}
   set timeofday [split $timeofday :]
   set hours [string trimleft [lindex $timeofday 0] 0]
   if {$hours == {}} {set hours 0}
   set minutes [string trimleft [lindex $timeofday 1] 0]
   if {$minutes == {}} {set minutes 0}
   expr ( $hours * 60 ) + $minutes
}

proc _randomize {random value} {
   if {$random == 0} {return $value}
   set t [clock clicks]
   if {$random == 1} {
      set result [expr $value + ( $t & $random )]
   } else {
      set result [expr $value + ( $t % $random )]
   }
   return $result
}

# The actual scheduler that executes the actions defined in the schedule.
#
proc _scheduler {} {

   global scheduledb

   set now [clock seconds]
   set today1 [clock format $now -format '%a']
   set today2 [clock format $now -format '%A']
   set now [_convertTimeOfDay [clock format $now -format %H:%M]]

   # Process all declared devices.
   #
   foreach dev [array names scheduledb dev.*.id] {
      set dev $scheduledb($dev)

      set action off
      set doitnow 0

      # Search if we are within an interval when the device must be "on".
      #
      foreach id $scheduledb($dev.sch) {

         set end $scheduledb($id.off)

         # Randomize the time interval each day.
         #
         if {$now == 0} {
            set r $scheduledb($id.random)
            set scheduledb($id.variableOn) [_randomize $r $scheduledb($id.on)]
            if {$end != {}} {
               set scheduledb($id.variableOff) [_randomize $r $end]
            }
         }

         if {$end != {}} {
            if {$now < $scheduledb($id.variableOn)} continue
            if {$now >= $scheduledb($id.variableOff)} continue
         } else {
            if {$now != $scheduledb($id.variableOn)} continue
         }

         # If specific days were specified, avoid any other day.
         #
         if {$scheduledb($id.days) != {}} {
            set r1 [lsearch -exact $scheduledb($id.days) $today1]
            set r2 [lsearch -exact $scheduledb($id.days) $today2]
            if {($r1 < 0) && ($r2 < 0)} continue
         }

         # We meet all the conditions for this interval.
         #
         set action on
      }

      set command $scheduledb($dev.$action)
      if {$command == "ignore"} {
         set scheduledb($dev.latest) $action
         continue
      }

      if {$scheduledb($dev.off) != "ignore"} {
         set doitnow 1
      }

      if {$scheduledb($dev.latest) != $action} {
         eventlog "executing $command"
         set scheduledb($dev.latest) $action
         set doitnow 1
      }

      if {$doitnow} {
         if {[catch [eval $command] msg]} {
            eventlog "failed $command ($msg)"
         }
      }
   }
}

# schedule - Add a new scheduled item.
#
# Syntax:
#     schedule device DEVICE ON OFF
#     schedule add -device DEVICE -random N -on HH:MM -off HH:MM -only {DAYS..}
#
# The OFF command is optional: if not present, no off action is taken.
#
# The -off time is also optional: if not present, the ON action is executed
# only once.
#
# The random value to apply to the schedule time will be between 0 and N
# minutes. Default: 0 (no randomization, use exact scheduled time).
#
# The -only option takes a list of days of the week. Each days of week is
# the full name of the day (Monday, Tuesday, ..) or the abbreviated version
# (Mon, Tue, ..).
#
proc schedule {action args} {

   global scheduledb scheduleid

   if {$action == "device"} {
      if {[llength $args] < 2} {
         error "invalid arguments"
      }
      set dev "dev.[lindex $args 0]"
      set scheduledb($dev.id) $dev
      set scheduledb($dev.on) [lindex $args 1]
      if {[llength $args] == 3} {
         set scheduledb($dev.off) [lindex $args 2]
      } else {
         set scheduledb($dev.off) ignore
      }
      set scheduledb($dev.latest) {}
      return
   }

   if {$action != "add"} {error "invalid action $action"}

   # Decode the arguments.
   #
   set random 0
   set device {}
   set on {}
   set off {}
   set days {}

   foreach {opt value} $args {
      switch -glob -- $opt {
         -random  {set random $value}
         -on      {set on $value}
         -off     {set off $value}
         -device  {set device $value}
         -only    {set day $value}
      }
   }

   if {$on == {}} {error "no on action time provided"}
   if {$device == {}} {error "no device provided"}

   # Add this scheduled interval to the database.
   #
   incr scheduleid
   set id "sch.$scheduleid"

   set scheduledb($id.id) $id
   set scheduledb($id.device) $device
   set scheduledb($id.start) $on
   set scheduledb($id.end) $off
   set scheduledb($id.days) $days
   set scheduledb($id.random) $random
   set scheduledb($id.on) [_convertTimeOfDay $on]
   set scheduledb($id.off) [_convertTimeOfDay $off]

   set scheduledb($id.variableOn) [_randomize $random $scheduledb($id.on)]
   if {$off != {}} {
      set scheduledb($id.variableOff) [_randomize $random $scheduledb($id.off)]
   }

   lappend scheduledb(dev.$device.sch) $id
}

# Load the local configuration.
#

if {[cget motionCenter] == {}} {
   # Vanilla TclHttpd config file: assume fixed location.
   #
   set scheduleConfigDir /storage/motion/config
} else {
   # Customized TclHttpd config file: use the configuration.
   #
   set scheduleConfigDir [file join [cget motionCenter] config]
}
foreach cf [list schedule.rc schedule.tcl] {
   set cfp [file join $scheduleConfigDir $cf]
   if {[file readable $cfp]} {
      source $cfp
   }
}

# Start the periodic scheduler
#
proc _scheduletimer {} {
   global scheduleIsActive

   if {$scheduleIsActive} _scheduler
   after 30000 _scheduletimer
}
_scheduletimer

