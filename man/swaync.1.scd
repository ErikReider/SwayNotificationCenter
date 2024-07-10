swaync(1)

# NAME

swaync - A simple notification daemon with a GTK gui for notifications and the control center

# USAGE

*swaync* [option]

# OPTIONS

*-h, --help*
	Show help options

*-v, --version*
	Prints version

*-s, --style* <CSS file>
	Use a custom Stylesheet file

*-c, --config* <Config file>
	Use a custom config file

# Control Center Keyboard Shortcuts

*Up/Down*: Navigate notifications

*Home*: Navigate to the latest notification

*End*: Navigate to the oldest notification

*Escape/Caps_Lock*: Close notification panel

*Return*: Execute default action or close notification if none

*Delete/BackSpace*: Close notification

*Shift+C*: Close all notifications

*Shift+D*: Toggle Do Not Disturb

*Buttons 1-9*: Execute alternative actions

*Left click button / actions*: Activate notification action

*Middle/Right click notification*: Close notification

# CONFIGURATION

The main config file is located in */etc/xdg/swaync/config.json*. Copy it over
to your *~/.config/swaync/* folder to customize without needing root access.

To reload the config, you'll need to run *swaync-client --reload-config*

For information on the config file format, see *swaync*(5)


# Scripting

Scripting rules and logic:

. *Only one* script can be fired per notification
. Each script requires `exec` and at least one of the other properties
. All listed properties must match the notification for the script to be ran
. If any of the properties doesn't match, the script will be skipped
. If a notification doesn't include one of the properties, that property will be skipped

Notification information can be printed into a terminal by running
*G_MESSAGES_DEBUG=all swaync* (when a notification appears).

Config properties:

```
{
	"scripts": {
		"example-script": {
			"exec": "Your shell command or script here...",
			"app-name": "Notification app-name Regex",
			"summary": "Notification summary Regex",
			"body": "Notification body Regex",
			"urgency": "Low or Normal or Critical",
			"category": "Notification category Regex"
		}
	}
	other non scripting properties...
}
```

*config.json* example:

```
{
	"scripts": {
		// This script will only run when Spotify sends a notification containing
		// that exact summary and body
		"example-script": {
			"exec": "~/.config/swaync/myRickRollScript.sh",
			"app-name": "Spotify"
			"summary": "Never Gonna Give You Up",
			"body": "Rick Astley - Whenever You Need Somebody"
		}
	}
	other non scripting properties...
}
```

## Disable scripting

To completely disable scripting, the project needs to be built like so:

```
meson build -Dscripting=false
ninja -C build
meson install -C build
```

# Waybar Example

This example requires *NotoSansMono Nerd Font* to get the icons looking right

Waybar config

```
"custom/notification": {
	"tooltip": false,
	"format": "{icon}",
	"format-icons": {
		"notification": "<span foreground='red'><sup></sup></span>",
		"none": "",
		"dnd-notification": "<span foreground='red'><sup></sup></span>",
		"dnd-none": "",
		"inhibited-notification": "<span foreground='red'><sup></sup></span>",
		"inhibited-none": "",
		"dnd-inhibited-notification": "<span foreground='red'><sup></sup></span>",
		"dnd-inhibited-none": ""
	},
	"return-type": "json",
	"exec-if": "which swaync-client",
	"exec": "swaync-client -swb",
	"on-click": "swaync-client -t -sw",
	"on-click-right": "swaync-client -d -sw",
	"escape": true
},
```

Waybar css file

```
#custom-notification {
	font-family: "NotoSansMono Nerd Font";
}
```
