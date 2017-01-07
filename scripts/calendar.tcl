# Generate the data necessary for generating a calendar.

if {[cget motionCenter] == {}} {
   # Vanilla TclHttpd config file: assume fixed location.
   #
   set motionConfig(videos) [file join storage motion videos]
} else {
   # Customized TclHttpd config file: use the configuration.
   #
   set motionConfig(videos) [file join [cget motionCenter] videos]
}

Direct_Url /api webApi

proc pathBuild {seconds} {
   global motionConfig
   return "$motionConfig(videos)/[clock format $seconds -format {%Y/%m/%d}]"
}

proc relativePathBuild {seconds} {
   return "[clock format $seconds -format {%Y/%m/%d}]"
}

proc webApi/monthly {year month} {

   if {[string match {[1-9]} $month]} {
      set month [format {%02d} $month]
   }
   set cursor [clock scan "$year $month 1 00:00:00" -format {%Y %m %d %H:%M:%S}]

   set result "\[null"

   while {[clock format $cursor -format {%m}] == $month} {

      set path [pathBuild $cursor]

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

proc timeCompare {v1 v2} {
   string compare [lindex [split $v1 {-}] 0] [lindex [split $v2 {-}] 0]
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
   set events [lsort -command timeCompare [glob -nocomplain *.avi]]
   if {$events == {}} {
      return "\[\]"
   }

   set sep "\["

   foreach video $events {
      # The JPEG associated with each event has the same root name
      # (use keyword "preview" in motion.cfg).
      #
      set time [lindex [split $video -] 0]
      set camera [join [lrange [split [lindex [split $video -] 1] {:}] 0 1] {:}]
      set jpg "[file rootname $video].jpg"
      if {[file exists $jpg]} {
         set jpg "\"$jpg\""
      } else {
         set jpg "null"
      }
      append result $sep "{\"cam\":\"$camera\",\"date\":\"$year/$month/$day\",\"time\":\"$time\",\"vid\":\"$video\",\"jpg\":$jpg}"
      set sep ","
   }
   cd $pwd
   return "${result}\]"
}

proc dumpStaticBinaryData {name} {

   set fd [open $name [list RDONLY BINARY]]
   set data [read $fd]
   close $fd
   return $data
}

set webApi/snapshot image/jpeg

proc webApi/snapshot {date jpg} {

   global motionConfig
   dumpStaticBinaryData [file join $motionConfig(videos) $date $jpg]
}

set webApi/avi video/x-msvideo

proc webApi/avi {date avi} {

   global motionConfig
   dumpStaticBinaryData [file join $motionConfig(videos) $date $avi]
}

# Today and Yesterday link.
# As a shortcut, mostly for Kodi access, create and keep up-to-date short
# links to the directories for todays's and yesterday's dates.
#
proc maintainLinks {root force} {

   set pwd [pwd]
   cd $root

   set forceToday 0
   set forceYesterday 0

   if {$force} {
      set forceToday 1
      set forceYesterday 1
   } else {
      set hour [clock format [clock seconds] -format {%H}]
      if {$hour == "00"} {
         set forceToday 1
         set forceYesterday 1
      }
      if {! [file exists Today]} {
         set forceToday 1
      }
      if {! [file exists Yesterday]} {
         set forceYesterday 1
      }
   }

   if {$forceToday} {
      file delete -force Today
      set todayDir [relativePathBuild [clock seconds]]
      if {[file exists $todayDir]} {
         file link -symbolic Today $todayDir
      }
   }

   if {$forceYesterday} {
      file delete -force Yesterday
      set yesterdayDir [relativePathBuild [clock add [clock seconds] -1 day]]
      if {[file exists $yesterdayDir]} {
         file link -symbolic Yesterday $yesterdayDir
      }
   }

   cd $pwd

   # Check again every 1/2 hour.
   after 1800000 {maintainLinks $root 0}
}

maintainLinks $motionConfig(videos) 1

