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

   foreach camera [lsort -command cameracompare [array names cameradb *.id]] {
      set camera $cameradb($camera)
      append result "${sep}{\"name\":\"$camera\",\"url\":\"$cameradb($camera.url)\",\"free\":\"$cameradb($camera.free)\",\"time\":\"[clock format $cameradb($camera.time)]\"}"
      set sep ","
   }
   append result "\]"

   return $result
}

# Eliminate one camera from the database.
#
proc camera_remove {id} {
   global cameradb
   foreach known [array names cameradb $id.*] {
      unset cameradb($known)
   }
}

# Eliminate any cameras for one given server.
#
proc camera_remove_server {server} {
   global cameradb
   foreach known [array names cameradb *.id] {
      set id $cameradb($known)
      set name [lindex [split $id :] 0]
      if {$name == $server} {
         camera_remove $id
      }
   }
}

# Eliminate any cameras not declared for more than two minutes.
#
proc camera_prune {} {
   set deadline [expr [clock seconds] - 120]
   global cameradb
   foreach known [array names cameradb *.id] {
      set id $cameradb($known)
      if {$cameradb($id.time) < $deadline} {
          camera_remove $id
      }
   }
   after 10000 camera_prune
}
camera_prune

# Declare one new camera.
#
proc camera {name url {available {}}} {
   global cameradb

   # Avoid assigning the same URL to multiple cameras. This can happen
   # after a camera reboot if the DHCP server assigned the same IP address
   # as another previously known camera witch lease expired.
   # (It does not matter that we delete this very camera as well, since
   # we are immediately re-createing the record.)
   #
   foreach known [array names cameradb *.id] {
      set known $cameradb($known)
      if {$cameradb($known.url) == $url} {
         camera_remove $known
      }
   }

   set cameradb($name.id) $name
   set cameradb($name.url) $url
   set cameradb($name.free) $available
   set cameradb($name.time) [clock seconds]
}

# Provide a web API for the cameras to declare themselves.
# This makes the server's configuration dynamic.
# Each camera server may declare a list of cameras, or be a camera itself.
#
proc webApiCamera/declare {name url available {devices {}}} {
   camera_remove_server $name
   if {$devices != {}} {
      foreach dev $devices {
         camera $name:$dev $url/$dev/stream $available
      }
   } else {
      camera $name $url $available
   }
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

