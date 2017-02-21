# Responds to requests for camera information.

Direct_Url /api/camera webApiCamera

proc webApiCamera/list {} {

   global cameradb

   set sep "\["

   foreach camera [lsort [array names cameradb]] {
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

