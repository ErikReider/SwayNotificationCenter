swaync(5)

# NAME

swaync - Configuration file

# CONFIGURATION

Using a text editor with a JSON language server is recommended when editing the
config file to be able to detect config errors

*positionX* ++
	type: string ++
	default: right ++
	values: left, right, center ++
	description: Horizontal position of control center and notification window

*positionY* ++
	type: string ++
	default: top ++
	values: top, bottom ++
	description: Vertical position of control center and notification window

*layer* ++
	type: string ++
	default: top ++
	values: background, bottom, top, overlay ++
	description: Layer of control center window relative to normal windows. background is below all windows, overlay is above all windows.

*cssPriority* ++
	type: string ++
	default: application ++
	values: application, user ++
	description: Which GTK priority to use when loading the default and user ++
		CSS files. Pick "user" to override *XDG_CONFIG_HOME/gtk-3.0/gtk.css*

*control-center-margin-top* ++
	type: integer ++
	default: 0 ++
	description: The margin (in pixels) at the top of the notification center. 0 to disable

*control-center-margin-bottom* ++
	type: integer ++
	default: 0 ++
	description: The margin (in pixels) at the bottom of the notification center. 0 to disable

*control-center-margin-right* ++
	type: integer ++
	default: 0 ++
	description: The margin (in pixels) at the right of the notification center. 0 to disable

*control-center-margin-left* ++
	type: integer ++
	default: 0 ++
	description: The margin (in pixels) at the left of the notification center. 0 to disable

*timeout* ++
	type: integer ++
	default: 10 ++
	description: The notification timeout for notifications with normal priority

*timeout-low* ++
	type: integer ++
	default: 5 ++
	description: The notification timeout for notifications with low priority

*timeout-critical* ++
	type: integer ++
	default: 0 ++
	description: The notification timeout for notifications with critical priority. 0 to disable

*notification-window-width* ++
	type: integer ++
	default: 500 ++
	description: Width of the notification in pixels

*keyboard-shortcuts* ++
	type: bool ++
	default: true ++
	description: If control center should use keyboard shortcuts

*image-visibility* ++
	type: string ++
	default: always ++
	values: always, when-available, never ++
	description: An explanation about the purpose of this instance.

*transition-time* ++
	type: integer ++
	default: 200 ++
	description: The notification animation duration. 0 to disable

*hide-on-clear* ++
	type: bool ++
	default: false ++
	description: Hides the control center after pressing "Clear All"

*hide-on-action* ++
	type: bool ++
	default: true ++
	description: Hides the control center when clicking on notification action

*fit-to-screen* ++
	type: bool ++
	default: true ++
	description: Whether the control center should expand vertically to fill the screen

*control-center-height* ++
	type: integer ++
	default: 500 ++
	description: The control centers height in pixels.
	This setting is ignored when _fit-to-screen_ it set to "true"

*control-center-width* ++
	type: integer ++
	default: 500 ++
	description: The control centers width in pixels

*notification-visibility* ++
	type: object ++
	visibility object properties: ++
		*state*++
			type: string ++
			optional: false ++
			default: enabled ++
			values: ignored, muted, transient, enabled ++
			description: The notification visibility state. ++
		*override-urgency*++
			type: string ++
			optional: true ++
			default: unset ++
			values: unset, low, normal, critical ++
			description: The new urgency for the notification if set.++
		*app-name*++
			type: string ++
			optional: true ++
			description: The app-name. Uses Regex.++
		*desktop-entry*++
			type: string ++
			optional: true ++
			description: The desktop-entry. Uses Regex.++
		*summary*++
			type: string ++
			optional: true ++
			description: The summary of the notification. Uses Regex.++
		*body*++
			type: string ++
			optional: true ++
			description: The body of the notification. Uses Regex.++
		*urgency*++
			type: string ++
			optional: true ++
			default: Normal ++
			values: Low, Normal, Critical ++
			description: The urgency of the notification.++
		*category*++
			type: string ++
			optional: true ++
			description: Which category the notification belongs to. Uses Regex.++
	description: Set the visibility or override urgency of each incoming ++
		notification. ++
		If the notification doesn't include one of the properties, that ++
		property will be ignored. All properties (except for state) use ++
		regex. If all properties match the given notification, the ++
		notification will be follow the provided state. ++
		Only the first matching object will be used. ++
	example:
```
{
	"notification-visibility": {
		"example-name": {
			"state": "The notification state",
			"app-name": "Notification app-name Regex",
			"summary": "Notification summary Regex",
			"body": "Notification body Regex",
			"urgency": "Low or Normal or Critical",
			"category": "Notification category Regex"
		}
	}
}
```

*widgets* ++
	type: array ++
	Default values: ["title", "dnd", "notifications"] ++
	Valid array values (see *widget-config* for more information): ++
		*notifications*++
			required: true ++
			optional: false ++
		*title*++
			optional: true ++
		*dnd*++
			optional: true ++
		*label*++
			optional: true ++
		*mpris*++
			optional: true ++
		*menubar*++
			optional: true ++
		*buttons-grid*++
			optional: true ++
		*inhibitors*++
			optional: true ++
	description: ++
		Which order and which widgets to display. ++
		If the \"notifications\" widget isn't specified, it ++
		will be placed at the bottom. ++
	multiple of same widget: ++
		Append a # with any value to the end of the widget name. ++
		Example: "title#TheMainTitle" ++
		To address this widget specifically in the css file use the css class .TheMainTitle ++
	example:
```
{
	"widgets": [
		"inhibitors",
		"title",
		"dnd",
		"notifications"
	]
}
```

*widget-config* ++
	type: object ++
	description: Configure specific widget properties. ++
	multiple of same widget: ++
		Append a # with any value to the end of the widget name. ++
		Example: "title#TheMainTitle" ++
		To address this widget specifically in the css file use the css class .TheMainTitle ++
	Widgets to customize: ++
		*title*++
			type: object ++
			css class: widget-title ++
			properties: ++
				text: ++
					type: string ++
					optional: true ++
					default: "Notifications" ++
					description: The title of the widget ++
				clear-all-button: ++
					type: bool ++
					optional: true ++
					default: true ++
					description: Whether to display a "Clear All" button ++
				button-text: ++
					type: string ++
					optional: true ++
					default: "Clear All" ++
					description: "Clear All" button text ++
			description: The notification visibility state. ++
		*dnd*++
			type: object ++
			css class: widget-dnd ++
			properties: ++
				text: ++
					type: string ++
					optional: true ++
					default: "Do Not Disturb" ++
					description: The title of the widget ++
			description: Control Center Do Not Disturb Widget. ++
		*label*++
			type: object ++
			css class: widget-label ++
			properties: ++
				text: ++
					type: string ++
					optional: true ++
					default: "Label Text" ++
					description: The text content of the widget ++
				clear-all-button: ++
					type: integer ++
					optional: true ++
					default: 5 ++
					description: The maximum lines ++
			description: A generic widget that allows the user to add custom text. ++
		*mpris*++
			type: object ++
			css classes: ++
				widget-mpris ++
				widget-mpris-player ++
				widget-mpris-title ++
				widget-mpris-subtitle ++
			properties: ++
				image-size: ++
					type: integer ++
					optional: true ++
					default: 96 ++
					description: The size of the album art. ++
				image-radius: ++
					type: integer ++
					optional: true ++
					default: 12 ++
					description: The border radius of the album art. ++
			description: A widget that displays multiple music players. ++
		*menubar*++
			type: object ++
			css classes: ++
				widget-menubar ++
				.widget-menubar>box>.menu-button-bar ++
				name of element given after menu or buttons with # ++
			patternProperties: ++
				menu#<name>: ++
					type: object ++
					properties: ++
						label: ++
							type: string ++
							optional: true ++
							default: "Menu" ++
							description: Label of button to show/hide menu dropdown ++
						position: ++
							type: string ++
							optional: true ++
							default: "right" ++
							description: Horizontal position of the button in the bar ++
							enum: ["right", "left"] ++
						animation-type: ++
							type: string ++
							optional: true ++
							default: "slide_down" ++
							description: Animation type for menu++
							enum: ["slide_down", "slide_up", "none"] ++
						animation-duration: ++
							type: integer ++
							optional: true ++
							default: 250 ++
							description: Duration of animation in milliseconds ++
						actions: ++
							type: array ++
							Default values: [] ++
							Valid array values: ++
								type: object ++
								properties: ++
									label: ++
										type: string ++
										default: "label" ++
										description: Text to be displayed in button ++
									command: ++
										type: string ++
										default: "" ++
										description: "Command to be executed on click" ++
							description: A list of actions containing a label and a command ++
					description: A button to reveal a dropdown with action-buttons ++
				buttons#<name>: ++
					type: object ++
					properties: ++
						position: ++
							type: string ++
							optional: true ++
							default: "right" ++
							description: Horizontal position of the buttons in the bar ++
							enum: ["right", "left"] ++
						actions: ++
							type: array ++
							Default values: [] ++
							Valid array values: ++
								type: object ++
								properties: ++
									label: ++
										type: string ++
										default: "label" ++
										description: Text to be displayed in button ++
									command: ++
										type: string ++
										default: "" ++
										description: "Command to be executed on click" ++
							description: A list of actions containing a label and a command ++
					description: A list of buttons to be displayed in the menu-button-bar ++
		*buttons-grid*++
			type: object ++
			css class: widget-buttons (access buttons with >flowbox>flowboxchild>button) ++
			properties: ++
				actions: ++
					type: array ++
					Default values: [] ++
					Valid array values: ++
						type: object ++
						properties: ++
							label: ++
								type: string ++
								default: "label" ++
								description: Text to be displayed in button ++
							command: ++
								type: string ++
								default: "" ++
								description: "Command to be executed on click" ++
					description: A list of actions containing a label and a command ++
			description: A grid of buttons that execute shell commands ++
		*volume*++
			type: object ++
			css class: ++
				widget-volume ++
				per-app-volume ++
			properties: ++
				label: ++
					type: string ++
					optional: true ++
					default: "Volume" ++
					description: Text displayed in front of the volume slider ++
				show-per-app: ++
					type: bool ++
					optional: true ++
					default: false ++
					description: Show per app volume control ++
				button-label-1: ++
					type: string ++
					optional: true ++
					default: "⇧" ++
					description: Label shown when per app control not shown ++
				button-label-2: ++
					type: string ++
					optional: true ++
					default: "⇩" ++
					description: Label shown when per app control shown ++
				animation-type: ++
					type: string ++
					optional: true ++
					default: "slide_down" ++
					description: Animation type for the per app volume control ++
					enum: ["slide_down", "slide_up", "none"] ++
				animation-duration: ++
					type: integer ++
					optional: true ++
					default: 250 ++
					description: Duration of animation in milliseconds ++
			description: Slider to control pulse volume ++
		*backlight*++
			type: object ++
			css class: widget-backlight ++
			properties: ++
				label: ++
					type: string ++
					optional: true ++
					default: "Brightness" ++
					description: Text displayed in front of the backlight slider ++
				device: ++
					type: string ++
					optional: true ++
					default: "intel_backlight" ++
					description: Device in `/sys/class/backlight` or `/sys/class/leds` ++
				subsystem: ++
					type: string ++
					optional: true ++
					default: "backlight" ++
					description: Kernel subsystem for brightness control ++
					enum: ["backlight", "leds"] ++
				min: ++
					type: integer ++
					optional: true ++
					default: 0 ++
					description: Lowest possible value for brightness ++
			description: Slider to control screen brightness ++
		*inhibitors*++
			type: object ++
			css class: widget-inhibitors ++
			properties: ++
				text: ++
					type: string ++
					optional: true ++
					default: "Inhibitors" ++
					description: The title of the widget ++
				clear-all-button: ++
					type: bool ++
					optional: true ++
					default: true ++
					description: Whether to display a "Clear All" button ++
				button-text: ++
					type: string ++
					optional: true ++
					default: "Clear All" ++
					description: "Clear All" button text ++
			description: Displayed if notifications are inhibited.

	example:
```
{
	"widget-config": {
		"title": {
			"text": "Notifications",
			"clear-all-button": true,
			"button-text": "Clear All"
		},
		"dnd": {
			"text": "Do Not Disturb"
		},
		"label": {
			"max-lines": 5,
			"text": "Label Text"
		},
		"mpris": {
			"image-size": 96,
			"image-radius": 12
		},
		"menubar": {
			"menu#power": {
				"label": "Power",
				"position": "right",
				"actions": [
					{
						"label": "Shut down",
						"command": "systemctl poweroff"
					},
					...
				]
			},
			"buttons#screenshot": {
				"position": "left",
				"actions": [
					{
						"label": "Screenshot",
						"command": "grim"
					},
					...
				]
			}
		},
		"buttons": {
			"actions": [
				{
					"label": "wifi",
					"command": "rofi-wifi-menu"
				},
				...
			]
		}
	}
}
```

# IF BUILT WITH SCRIPTING

*script-fail-notify* ++
	type: bool ++
	default: true ++
	description: Sends a notification if a script fails to run

*scripts* ++
	type: object ++
	script object properties: ++
		*exec*++
			type: string ++
			optional: false ++
			description: The script to run. Can also run regular shell commands.++
		*app-name*++
			type: string ++
			optional: true ++
			description: The app-name. Uses Regex.++
		*desktop-entry*++
			type: string ++
			optional: true ++
			description: The desktop-entry. Uses Regex.++
		*summary*++
			type: string ++
			optional: true ++
			description: The summary of the notification. Uses Regex.++
		*body*++
			type: string ++
			optional: true ++
			description: The body of the notification. Uses Regex.++
		*urgency*++
			type: string ++
			optional: true ++
			default: Normal ++
			values: Low, Normal, Critical ++
			description: The urgency of the notification.++
		*category*++
			type: string ++
			optional: true ++
			description: Which category the notification belongs to. Uses Regex.++
		*run-on*++
			type: string ++
			optional: true ++
			values: action, receive ++
			default: receive ++
			description: Whether to run this action when the notification is ++
						 received, or when an action is taken on it. ++
	description: Which scripts to check and potentially run for every ++
		notification. If the notification doesn't include one of the properties, ++
		that property will be ignored. All properties (except for exec) use regex. ++
		If all properties match the given notification, the script will be run. ++
		Only the first matching script will be run. ++
	example:
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
}
```

	You can also use these environment variables in your script:
```
SWAYNC_BODY="Notification body content"
SWAYNC_DESKTOP_ENTRY="Desktop entry"
SWAYNC_URGENCY="Notification urgency"
SWAYNC_TIME="Notification time"
SWAYNC_APP_NAME="Notification app name"
SWAYNC_CATEGORY="SwayNC notification category"
SWAYNC_REPLACES_ID="ID of notification to replace"
SWAYNC_ID="SwayNC notification ID"
SWAYNC_SUMMARY="Notification summary"
```
