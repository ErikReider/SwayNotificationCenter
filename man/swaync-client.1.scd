swaync-client(1)

# NAME

swaync-client - Client executable

# USAGE

*swaync-client* [option]

# OPTIONS

*-h, --help*
	Show help options

*-v, --version*
	Prints version

*-R, --reload-config*
	Reload the config file

*-rs, --reload-css*
	Reload the css file. Location change requires restart

*-t, --toggle-panel*
	Toggle the notification panel

*-op, --open-panel*
	Opens the notification panel

*-cp, --close-panel*
	Closes the notification panel

*-d, --toggle-dnd*
	Toggle and print the current dnd state

*-D, --get-dnd*
	Print the current dnd state

*-dn, --dnd-on*
	Turn dnd on and print the new dnd state

*-df, --dnd-off*
	Turn dnd off and print the new dnd state

*-I, --get-inhibited*
	Print if currently inhibited or not

*-In, --get-num-inhibitors*
	Print number of inhibitors

*-Ia, --inhibitor-add [APP_ID]*
	Add an inhibitor

*-Ir, --inhibitor-remove [APP_ID]*
	Remove an inhibitor

*-Ic, --inhibitors-clear*
	Clears all inhibitors

*-c, --count*
	Print the current notification count

*--hide-latest*
	Hides latest notification. Still shown in Control Center

*--close-latest*
	Closes latest notification

*-C, --close-all*
	Closes all notifications

*-a, --action [ACTION_INDEX]*
	Invokes the action [ACTION_INDEX] (or 0) of the latest notification

*-sw, --skip-wait*
	Doesn't wait when swaync hasn't been started

*-s, --subscribe*
	Subscribe to notification add and close events

*-swb, --subscribe-waybar*
	Subscribe to notification add and close events with waybar support. Read README for example
