# Responds to requests for camera information.

Direct_Url /api/camera webApiCamera

proc cameracompare {a b} {

   set la [string length $a]
   set lb [string length $b]

   if {$la < $lb} {
      return -1
   } elseif {$la > $lb} {
      return 1
   }
   return [string compare $a $b]
}

proc webApiCamera/list {} {

   global cameradb

   set sep "\["

   foreach camera [lsort -command cameracompare [array names cameradb]] {
      append result "${sep}{\"name\":\"$camera\",\"url\":\"$cameradb($camera)\"}"
      set sep ","
   }
   append result "\]"

   return $result
}

# Declare a new camera.
#
proc camera {name url} {
   global cameradb

   # Avoid assigning the same URL to multiple cameras. This can happen
   # after a camera reboot if the DHCP server assigned the same IP address
   # as another previously known camera witch lease expired.
   # (It does not matter that we delete this very camera as well, since
   # we are immediately re-createing the record.)
   #
   foreach known [array names cameradb] {
      if {$cameradb($known) == $url} {
         unset cameradb($known)
      }
   }

   set cameradb($name) $url
}

# Provide a web API for the cameras to declare themselves.
# This makes the server's configuration dynamic.
#
proc webApiCamera/declare {name url} {
   camera $name $url
}

# Load the local configuration.
#
if {[cget motionCenter] == {}} {
   # Vanilla TclHttpd config file: assume fixed location.
   #
   set cameraConfigDir /storage/motion/config
} else {
   # Customized TclHttpd config file: use the configuration.
   #
   set cameraConfigDir [file join [cget motionCenter] config]
}
foreach cf [list camera.rc camera.tcl] {
   set cfp [file join $cameraConfigDir $cf]
   if {[file readable $cfp]} {
      source $cfp
   }
}

