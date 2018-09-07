# Responds to requests for recordings information.

lappend motionCenter(storage) [list /storage "Video Storage"]

Direct_Url /api/dvr webApiDvr

proc webApiDvr/usage {} {

   global motionCenter

   set data [disk info]
   set sep "\["

   foreach s $motionCenter(storage) {
      set path [lindex $s 0]
      set name [lindex $s 1]
      append result $sep
      append result "{\"volume\":\"$path\",\"name\":\"$name\",\"size\":[expr [disk space $data $path] / 1024],\"usage\":[disk use $data $path]}"
   }
   return "${result}\]"
}

