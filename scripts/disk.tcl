#---------------------------------------------------------------
# $Id: 4187,v 1.39 2007-01-17 19:00:44 jcw Exp $
# Original W. Wright 5/14/2004 
# Contact via: http://lidar.wff.nasa.gov
# <<<<<<<< Linux/Unix only >>>>>>>>>>>>>>
#
# Return current disk drive information from
# Linux/Unix based systems.
#
# This proc simply runs the "df" command to capture the
# system disk drive usage information.  df is very fast.
#
# Examples:
#
# disk info                       
# Returns info for all drives.  Use this to get the $info data
# used by the mount and partition commands.
#
# disk partition [disk info] /dev/hda1 
# Returns a list containing information for partition /dev/hda1
# 
# disk mount [disk info] /
# Returns a list containing information for the partition
# mounted on /
#
# To use to gather drive information for multiple partitions
# or mounts use it as follows:
# set lst [ disk info ]
# disk partition $lst /dev/hda1
# disk partition $lst /dev/hdb1
# disk partition $lst /dev/ram0
#
#
# Additions by Pascal Martin 9/2/2018:
#
# disk mount /
# Same as: disk mount [disk info] /
#
# disk partition /dev/hda1
# Same as: disk partition [disk info] /dev/hda1
#
# disk use /
# disk use [disk info] /
# Returns a number indicating the percentage of disk space used
# for the partition mounted on /.
#
# disk use /dev/sda1
# disk use [disk info] /dev/sda1
# Returns a number indicating the percentage of disk space used
# for partition /dev/sda1.
#
# disk size /
# disk size [disk info] /
# disk size /dev/sda1
# disk size [disk info] /dev/sda1
# Returns a number indicating the size in KB of the partition mounted
# on /, or for partition /dev/sda1.
#
# disk device /
# disk device [disk info] /
# Returns the name of the device for the partition mounted on /.
#
# disk clean 80 /path
# Remove the oldest files and directories in /path until the space used
# is lower that 80%. This never removes file less than 7 days old.
#
#---------------------------------------------------------------
proc disk { cmd args } {
   switch -glob $cmd {
      info {
         set f [ open "|/bin/df" "r" ]
         regsub -all { +} [ read $f ]  " " lst
         close $f
         regsub -all {%} $lst "" lst
         return [ lrange [ split $lst "\n\r" ] 1 end-1]
      }

      m* -
      p* {
         if {[llength $args] == 1} {
            set lst [disk info]
            set a   [lindex $args 0]
         } else {
            set lst [ lindex $args 0 ]
            set   a [ lindex $args 1 ]
         }
         foreach  p $lst {
            switch -glob $cmd {
               p* { set d       [ lindex $p   0   ] }
               m* { set d       [ lindex $p end   ] }
            }
            if { [ string equal [ lindex $d 0 ] $a ] } {
               return $p
            }
         }
         error "invalid partition or mount point $a"
      }

      s* -
      u* {
         if {[llength $args] == 1} {
            set lst [disk info]
            set   a [lindex $args 0]
         } else {
            set lst [lindex $args 0]
            set   a [lindex $args 1]
         }
         foreach p $lst {
            switch -glob $cmd {
               s* { set r [lindex $p 1] }
               u* { set r [lindex $p end-1] }
            }
            if { [string equal [lindex $p 0] $a] } {
               return $r
            }
            if { [string equal [lindex $p end] $a] } {
               return $r
            }
         }
         error "invalid partition or mount point $a"
      }

      d* {
         if {[llength $args] == 1} {
            set lst [disk info]
            set   a [lindex $args 0]
         } else {
            set lst [lindex $args 0]
            set   a [lindex $args 1]
         }
         foreach p $lst {
            if { [string equal [lindex $p end] $a] } {
               return [lindex $p 0]
            }
         }
         error "invalid mount point $a"
      }

      c* {
         if {[llength $args] != 2} {error "bad arguments"}
         set limit [lindex $args 0]
         set path [lindex $args 1]
         set days 91
         while {$day > 7 && [disk use $path] > 85} {
             set old [exec /usr/bin/find $path -type d -ctime +[incr days -1]]
             foreach d [split $old "\n"] {
                 if {$d == $path} continue
                 if {$d == {}} continue
                 if {$d == {/}} continue
                 if {$d == {/usr}} continue
                 if {$d == {/bin}} continue
                 if {$d == {/lib}} continue
                 if {$d == {/etc}} continue
                 catch {exec /bin/rm -rf $d}
             }
         }
      }
   }
   error "invalid command $cmd"
}

