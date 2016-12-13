# motionCenter
A web site based on tclhttpd to provide control of a swarm of motion-equipped cameras.

This software is intended to work with tclhttpd, a pure Tcl HTTP server, and motion, a motion-detection software. Motion must be configured to save all detection files to a file server also accessible to the web server. Motion must be configured as follow:

snapshot_filename %Y/%m/%d/hostname>:camera-%H:%M:%S-snapshot

picture_filename %Y/%m/%d/hostname:camera-%H:%M:%S-%q

movie_filename %Y/%m/%d/hostname:camera-%H:%M:%S

timelapse_filename %Y/%m/%d/hostname:camera-timelapse

where hostname is the name of the machine where motion runs and camera identifies one camera monitored by this motion server. The ":camera" portion is optional, it may be omitted if this motion server monitors only one camera.

- Goal 1: visualise all motion detection events in a web page that shows a per-month calendar and a daily timeline.
- Goal 2: central motion configuration.
- goal 3: graphical edit of motion mask.
