# This is a very simple scheduler: schedule Tcl commands at predefined
# times of day, with an optional randomized variance and the ability
# to specify some days of the week.

# -- Schedule Web User Interface. ----------------------------------------

Direct_Url /api/schedule webApiSchedule

proc webApiSchedule/list {} {

   global scheduledb

   set sep "\["

   foreach id [lsort [array name scheduledb *.id]] {
      set id $scheduledb($id)
      set c $scheduledb($id.command)
      set d $scheduledb($id.days)
      set t $scheduledb($id.timeofday)
      set r $scheduledb($id.random)
      append result "${sep}{\"id\":\"$id\",\"days\":\"$d\",\"time\":\"$t\",\"random\":$r,\"cmd\":\"$c\"}"
      set sep ","
   }
   append result "\]"

   return $result
}


# -- Schedule Configuration and Execution. -------------------------------

set scheduleid 0

proc eventlog {text} {
   set f [open /var/lib/motion/schedulelog.txt a]
   puts $f "[clock format [clock seconds]]: $text"
   close $f
}

proc _scheduleExecute {id} {

   global scheduledb

   # Arm a new timer for the next deadline.
   #
   set now [clock seconds]
   set next $scheduledb($id.deadline)
   incr next 86400
   set scheduledb($id.deadline) $next
   if {$scheduledb($id.random)} {
      incr next [expr [clock clicks] % $scheduledb($id.random)]
   }
   incr next -$now
   after [expr $next * 1000] "_scheduleExecute $id"

   # Execute the requested command, if enabled for that day.
   #
   if {$scheduledb($id.days) != {}} {
      set today [clock format $now -format '%A']
      set r1 [lsearch -exact $scheduledb($id.days) $today]

      set today [clock format $now -format '%a']
      set r2 [lsearch -exact $scheduledb($id.days) $today]

      if {($r1 < 0) && ($r2 < 0)} return
   }
   eventlog "executing $scheduledb($id.command)"

   if {[catch {eval $scheduledb($id.command)} msg]} {
      eventlog "failed $scheduledb($id.command) ($msg)"
   }
}

# schedule - Add a new scheduled item.
#
# Syntax:
#         schedule -random N -time HH:MM -command {...} -only {DAYS..}
#
# The random value to apply to the schedule time will be between 0 and N
# seconds. Default: 0 (no randomization, use exact scheduled time).
#
# The -only option takes a list of days of the week. Each days of week is
# the full name of the day (Monday, Tuesday, ..) or the abbreviated version
# (Mon, Tue, ..).
#
proc schedule {args} {

   # Decode the arguments.
   #
   set ramdon 0
   set command {}
   set timeofday {}
   set daysofweek {}

   foreach {opt value} $args {
      switch -glob -- $opt {
         -random  {set random $value}
         -time    {set timeofday $value}
         -command {set command $value}
         -only    {set daysofweek $value}
      }
   }

   if {$timeofday == {}} {error "no time provided"}
   if {$command == {}} {error "no command provided"}

   # Calculate the next wakeup deadline.
   #
   set now [clock seconds]
   set today [clock format $now -format {%Y/%m/%d}]
   set next [clock scan "$today $timeofday" -format {%Y/%m/%d %H:%M}]
   if {$now > $next} {
      incr next 86400
   }

   # Add this scheduled item to the database.
   #
   global scheduledb scheduleid

   incr scheduleid
   set id "sch$scheduleid"

   set scheduledb($id.id) $id
   set scheduledb($id.command) $command
   set scheduledb($id.deadline) $next
   set scheduledb($id.random) $random
   set scheduledb($id.timeofday) $timeofday
   set scheduledb($id.days) $daysofweek

   # Start the initial timer.
   #
   if {$random} {
      set random [expr [clock clicks] % $random]
      incr next $random
   }
   incr next -$now
   after [expr $next * 1000] "_scheduleExecute $id"
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

