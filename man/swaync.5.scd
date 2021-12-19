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
			values: ignored, muted, enabled ++
			description: The notification visibility state. ++
		*app-name*++
			type: string ++
			optional: true ++
			description: The app-name. Uses Regex.++
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
	description: Set the visibility of each incoming notification. ++
		If the notification doesn't include one of the properites, that ++
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
	description: Which scripts to check and potentially run for every ++
		notification. If the notification doesn't include one of the properites, ++
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
