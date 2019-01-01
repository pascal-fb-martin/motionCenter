# A test script for the schedule function.

proc cget {name} {return "/invalid"}

proc Direct_Url {args} {}

source ../scripts/schedule.tcl

proc eventlog {args} {
   puts "Event: [join $args]"
}

proc testaction {state id} {

   global tstart done

   if {[clock seconds] > [expr $tstart + 600]} {set done 1}
   if {$id == "test2"} {
      if {$state == "off"} {error "invalid $state action for $id"}
   }

   puts "Executing action $state for device $id at [clock format [clock seconds] -format %H:%M]"
}

schedule device test1 {testaction on test1} {testaction off test1}
schedule device test2 {testaction on test2}

set tstart [clock seconds]

schedule add -device test1 -on [clock format [expr $tstart + 60] -format %H:%M] -off [clock format [expr $tstart + 120] -format %H:%M]

schedule add -device test1 -on [clock format [expr $tstart + 180] -format %H:%M] -off [clock format [expr $tstart + 300] -format %H:%M] -random 1

schedule add -device test1 -on [clock format [expr $tstart + 420] -format %H:%M] -random 3

schedule add -device test2 -on [clock format [expr $tstart + 60] -format %H:%M]

schedule add -device test2 -on [clock format [expr $tstart + 180] -format %H:%M] -random 1

schedule add -device test2 -on [clock format [expr $tstart + 300] -format %H:%M] -off [clock format [expr $tstart + 360] -format %H:%M]

puts [webApiSchedule/devices]
puts [webApiSchedule/list]
vwait done

