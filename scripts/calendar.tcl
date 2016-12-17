# Generate the data necessary for generating a calendar.

set motionConfig(videos) [file join storage motion videos]

Direct_Url /api webApi

proc webApi/monthly {year month} {

   global motionConfig

   if {[string match {[1-9]} $month]} {
      set month [format {%02d} $month]
   }
   set cursor [clock scan "$year $month 1 00:00:00" -format {%Y %m %d %H:%M:%S}]

   set result "\[null"

   while {[clock format $cursor -format {%m}] == $month} {

      set path "$motionConfig(videos)/[clock format $cursor -format {%Y/%m/%d}]"

      if {[file isdirectory $path]} {
         append result ",{\"hasrecords\":true}"
      } else {
         append result ",{\"hasrecords\":false}"
      }

      set cursor [clock add $cursor 1 day]
   }
   append result "\]"

   return $result
}

proc webApi/daily {year month day} {

   global motionConfig

   if {[string match {[1-9]} $month]} {
      set month [format {%02d} $month]
   }
   if {[string match {[1-9]} $day]} {
      set day [format {%02d} $day]
   }
   set path [file join $motionConfig(videos) $year $month $day]
   set webpath [file join $year $month $day]

   set pwd [pwd]
   if {[catch {cd $path}]} {
      return "\[\]"
   }
   set events [lsort [glob -nocomplain *.avi]]
   if {$events == {}} {
      return "\[\]"
   }

   set sep "\["

   # Retrieve the JPEG associated with each event.
   foreach snapshot [glob -nocomplain *.jpg] {
      set splitted [split $snapshot {-}]
      set snapshotdb([lindex $splitted 0]-[lindex $splitted 1]) $snapshot
   }
   foreach video $events {
      set id [split [file rootname $video] {-}]
      set server [lindex $id 0]
      set time [lindex $id 1]
      set jpg {}
      set cursor [clock scan "$year $month $day $time" -format {%Y %m %d %H:%M:%S}]
      for {set i 0} {$i < 120} {incr i} {
         set index "${server}-[clock format $cursor -format {%H:%M:%S}]"
         if {[info exists snapshotdb($index)]} {
            set jpg $snapshotdb($index)
            break
         }
         set cursor [clock add $cursor 1 seconds]
      }
      if {$jpg == {}} {
         set jpg "null"
      } else {
         set jpg "\"$jpg\""
      }
      append result $sep "{\"date\":\"$year/$month/$day\",\"time\":\"$time\",\"vid\":\"$video\",\"jpg\":$jpg}"
      set sep ","
   }
   cd $pwd
   return "${result}\]"
}

set webApi/snapshot image/jpeg

proc webApi/snapshot {date jpg} {

   global motionConfig

   set fd [open [file join $motionConfig(videos) $date $jpg] [list RDONLY BINARY]]
   set data [read $fd]
   close $fd

   return $data
}

set webApi/video video/x-msvideo
#set webApi/video video/mp4

proc webApi/video {date avi} {

   global motionConfig

   set fd [file open [file join $motionConfig(videos) $year $month $day $avi] r]
   set data [read $fd]
   close $fd

   return $data
}

