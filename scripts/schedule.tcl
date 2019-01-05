# This is a very simple scheduler: schedule Tcl commands at predefined
# times of day, with an optional randomized variance and the ability
# to specify some days of the week.

# -- Schedule Web User Interface. ----------------------------------------

Direct_Url /api/schedule webApiSchedule

proc webApiSchedule/list {} {

   global scheduledb

   set sep "\["

   foreach id [lsort [array names scheduledb sch.*.id]] {
      set id $scheduledb($id)
      set c $scheduledb($id.device)
      set d $scheduledb($id.days)
      set s $scheduledb($id.start)
      set e $scheduledb($id.end)
      set r $scheduledb($id.random)
      set l $scheduledb(dev.$c.latest)
      append result "${sep}{\"id\":\"$id\",\"days\":\"$d\",\"start\":\"$s\",\"end\":\"$e\",\"random\":$r,\"dev\":\"$c\",\"latest\":\"$l\"}"
      set sep ","
   }
   if {$sep != ","} {append result $sep}
   append result "\]"

   return $result
}

proc webApiSchedule/add {device start {end {}} {days {}} {random {}}} {
   schedule add -device $device -on $start -off $end -only $days -random $random
   saveschedule
}

proc webApiSchedule/delete {id} {
   schedule delete $id
   saveschedule
}

proc webApiSchedule/devices {} {

   global scheduledb

   set sep "\["

   foreach id [lsort [array names scheduledb dev.*.id]] {
      set id $scheduledb($id)
      set na $scheduledb($id.name)
      set n $scheduledb($id.on)
      set f $scheduledb($id.off)
      if {$scheduledb($id.sch) != {}} {
          set ll [llength $scheduledb($id.sch)]
          set d "\[\"[lindex $scheduledb($id.sch) 0]\""
          for {set i 1} {$i < $ll} {incr i} {
             append d ",\"[lindex $scheduledb($id.sch) $i]\""
          }
          append d "\]"
      } else {
         set d "\[\]"
      }
      append result "${sep}{\"id\":\"$id\",\"name\":\"$na\",\"on\":\"$n\",\"off\":\"$f\", \"sch\":$d}"
      set sep ","
   }
   if {$sep != ","} {append result $sep}
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
      set command $scheduledb($dev.off)
      if {$command == "ignore"} continue
      eventlog "executing $command"

      if {[catch {eval $command} msg]} {
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

proc ignore {} {}

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

      # If there is no scheduled action at all for a given device, take
      # this as a hint that the scheduler should not touch it at all.
      #
      if {$scheduledb($dev.sch) == {}} continue

      set action off
      set doitnow 0

      # Search if we are within an interval when the device must be "on".
      #
      foreach id $scheduledb($dev.sch) {

         if {[catch {set end $scheduledb($id.off)}]} continue

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
         eventlog "executing scheduled command $command"
         set scheduledb($dev.latest) $action
         set doitnow 1
      }

      if {$doitnow} {
         if {[catch {eval $command} msg]} {
            if {! $scheduledb($dev.error)} {
               eventlog "failed $command ($msg)"
            }
	    set scheduledb($dev.error) 1
         } else {
	    set scheduledb($dev.error) 0
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
      set scheduledb($dev.name) [lindex $args 0]
      set scheduledb($dev.on) [lindex $args 1]
      if {[llength $args] == 3} {
         set scheduledb($dev.off) [lindex $args 2]
      } else {
         set scheduledb($dev.off) ignore
      }
      set scheduledb($dev.latest) {}
      if {! [info exists scheduledb($dev.sch)]} {
         set scheduledb($dev.sch) {}
      }
      set scheduledb($dev.error) 0
      return
   }

   if {$action == "delete"} {
      foreach id $args {
          foreach e [list id device start end days random on off variableOn variableOff] {
             unset -nocomplain scheduledb($id.$e)
          }
          foreach dev [array names scheduledb dev.*.id] {
             set dev $scheduledb($dev)
             set index [lsearch -exact $scheduledb($dev.sch) $id]
             if {$index >= 0} {
                set scheduledb($dev.sch) [lreplace $scheduledb($dev.sch) $index $index]
             }
          }
      }
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
         -only    {set days $value}
      }
   }

   if {! [info exists scheduledb(dev.$device.id)]} {
      error "device $device not defined"
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

proc saveschedule {} {

   global scheduledb liveschedule

   if {[catch {set fd [open $liveschedule w]} msg]} {
      eventlog "cannot save configuration to $liveschedule"
      return
   }

   foreach id [lsort [array names scheduledb dev.*.id]] {
      set id $scheduledb($id)
      set na $scheduledb($id.name)
      set n $scheduledb($id.on)
      set f $scheduledb($id.off)
      puts $fd "schedule device $na {$n} {$f}"
   }

   foreach id [lsort [array names scheduledb sch.*.id]] {
      set id $scheduledb($id)
      set c $scheduledb($id.device)
      set d $scheduledb($id.days)
      set s $scheduledb($id.start)
      set e $scheduledb($id.end)
      set r $scheduledb($id.random)
      puts $fd "schedule add -device $c -on $s -off $e -only {$d} -random $r"
   }
   close $fd
}

# Load the local configuration.
# There are two main configurations:
#
# - schedule.live represents the configuration as was last active, including
#   online changes. This file is updated on restart or on online changes.
#
# - schedule.rc represents a static configuration, before any online change.
#   That file is never modified by the application.
#
# On start, the application loads the most recent file only. This allows
# resetting the configuration to a known state.

if {[cget motionCenter] == {}} {
   # Vanilla TclHttpd config file: assume fixed location.
   #
   set scheduleConfigDir /storage/motion/config
} else {
   # Customized TclHttpd config file: use the configuration.
   #
   set scheduleConfigDir [file join [cget motionCenter] config]
}
set liveschedule [file join $scheduleConfigDir schedule.live]

set reftime 0
set refcfg {}
foreach cf [list schedule.live schedule.rc] {
   set cfp [file join $scheduleConfigDir $cf]
   if {[file readable $cfp]} {
      set curtime [file mtime $cfp]
      if {$curtime > $reftime} {
         set refcfg $cfp
	 set reftime $curtime
      }
   }
}
if {$refcfg != {}} {
   eventlog "loading configuration from $refcfg"
   source $refcfg
   if {! [file readable $liveschedule]} {
      saveschedule
   } elseif {[file mtime $liveschedule]] < $reftime} {
      saveschedule
   }
}

# Start the periodic scheduler
#
proc _scheduletimer {} {
   global scheduleIsActive

   if {$scheduleIsActive} {
      if {[catch _scheduler msg]} {
         eventlog "scheduler error: $msg"
      }
   }
   after 30000 _scheduletimer
}
_scheduletimer

