# motionCenter

## Overview

A web site based on tclhttpd to provide control of a swarm of motion-equipped cameras.

This software is intended to work with tclhttpd, a pure Tcl HTTP server, and motion, a motion-detection software.

The web interface provides 2 main pages:
- A calendar page to visualise all motion detection events. This page shows a per-month calendar and a daily timeline for the selected day.
- A live video page to shows all configured cameras.

This software is also capable of controlling Orvibo S20 WiFi sockets. These controls can be scheduled on and off at specific times of day, for specific days of the week. (The intend is to have in the future motion detection events to trigger light controls, e.g. light up backyard or front porche lights when movement is detected in this area.)

## Architecture

The motionCenter software was designed for independent cameras controlled by the Motion software feeding a file server with motion capture videos. It provides a web interface built on tclhttpd, which gives access to these capture files.

It is possible to use a separate computer for each camera, the file server and the web server. In this case, it is assumed that access to the file server is provided using NFS and automount (using automount is critical for the system to recover properly from power outages).

Running the Motion software on the DVR itself may causes some significant CPU usage due to motion detection and video compression. Distributing the motion software over multiple small computers (e.g. Raspberry Pi 3 or FriendlyArm's Nanopi NEO) also makes the cabling easy when using analog cameras or USB webcams.

The typical configuration is to run the web server on the file server (a.k.a. DVR) and the Motion software on satellite (diskless) small computers.

## File Organization.

Each motion capture event is identified by:
- a date (as a tree of directories: year, month, day).
- a time of day.
- a camera identifier.

Each event is made of two files:
- a JPEG picture that identifies the detected motion (see Motion's configuration).
- a video file (only the MPEG4 / AVI format is supported for now).

See the file naming convention defined in the Motion configuration section below.

## tclhttpd Configuration

The recommended configuration for tclhttpd is a follow:

- Install the original tclhttpd software in /opt/tclhttpd
- Install the tclhttpd configuration (tclhttpd.rc) as /etc/default/tclhttpd.
- Use the init script provided with motionCenter.

In addition, a patch must be applied to file lib/config.tcl. In proc
config::init, replace:

   interp expose $i file

with:

   interp alias $i file {} file

The patch above is required because commit 35240baf0f4a245213ba4bf22e7310df06c6673d (2012) to the Tcl software changed the safe interpreter to block specific (deemed unsafe) subcommands of "file". The workaround is to execute "file" in the parent instead. This might break the security intent, but the official safe list is too restricted. Apparently tclhttpd.rc uses "file join", "file direname" and "file exists". "file dirname" was not listed as safe since this commit.

## Motion Configuration

Motion must be configured to save all detection files to a file server also accessible to the web server. Motion must be configured as follow:

snapshot_filename %Y/%m/%d/hostname:camera-%H:%M:%S-snapshot

picture_filename %Y/%m/%d/hostname:camera-%H:%M:%S-%q

movie_filename %Y/%m/%d/hostname:camera-%H:%M:%S

timelapse_filename %Y/%m/%d/hostname:camera-timelapse

where hostname is the name of the machine where motion runs and camera identifies one camera monitored by this motion server. The ":camera" portion is optional, it may be omitted if this motion server monitors only one camera.

## Installing and Configuring motionCenter

The motionCenter software should be installed using the install.sh script. It is organized as follow:
- directory scripts contains the motionCenter software.
- directory public contains the motionCenter web pages.
- directory config contains the configuration files. You will need to edit theses files.
- directory videos is populated with the motion capture files.

The motionCenter system configuration is organized as follow:

The tclhttpd configuration (e.g. /etc/default/tclhttpd) is extended to define the installation path for the motionCenter software: Config motionCenter _path_.

The config/cameras.rc file declares the list of cameras. Each line defines a camera name and URI for one camera. This is used for the live video mosaic. For example:

   camera cam1 camserver1:8081

   camera cam2 camserver2:8081

   ...

The config/orvibo.rc file declares the Orvibo WiFi sockets. Each line defines a name, MAC address and IP address for one socket. For example:

   orvibo declare wiwo1 DEADBEEF0001 192.168.1.151

   orvibo declare wiwo2 DEADBEEF0002 192.168.1.152

   ...

the config/schedule.rc file defines the commands to execute at a specific time of the week. Each line defines the time, day of week, a randomization range and the Tcl command to execute. For example:

   schedule -random 600 -time 05:30 -only Monday -command {orvibo on wiwo1}

   schedule -random 600 -time 09:30 -only Monday -command {orvibo off wiwo1}

   ...

