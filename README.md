# SwayNotificationCenter

[![Check PKGBUILD builds for Arch.](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/PKGBUILD-build.yml/badge.svg)](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/PKGBUILD-buildd.yml)
[![Check build for Fedora.](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/fedora-build.yml/badge.svg)](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/fedora-build.yml)
[![Check build for latest Ubuntu LTS.](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/ubuntu-build.yml/badge.svg)](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/ubuntu-build.yml)
[![Linting](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/linting.yml/badge.svg)](https://github.com/ErikReider/SwayNotificationCenter/actions/workflows/linting.yml)

A simple notification daemon with a GTK gui for notifications and the control center

*Note: SwayNotificationCenter only supports Desktops / Window Managers that
support `wlr_layer_shell_unstable_v1` like Sway or anything wlroots based*

*Note 2: SwayNotificationCenter does not support third-party GTK3 themes and is
only tested with the default GTK **Adwaita** theme. Usage of any third-party
theme might require extra tweaks to the default CSS style file*

## Demo

https://github.com/user-attachments/assets/5c054ac3-90bb-483e-a8f2-5af191805f04

My own [config](https://github.com/ErikReider/Linux/tree/master/dotfiles/.config/swaync):

<img width="655" height="829" alt="Config" src="https://github.com/user-attachments/assets/5993cbb2-a54d-4d1c-9289-b7e2b9d0a09f" />

## Table of Contents

  * [Want to show off your sick config?](#want-to-show-off-your-sick-config)
  * [Features](#features)
  * [Available Widgets](#available-widgets)
  * [Planned Features](#planned-features)
  * [Install](#install)
     * [Arch](#arch)
     * [Fedora](#fedora)
     * [Fedora Silverblue (and other rpm-ostree variants)](#fedora-silverblue-and-other-rpm-ostree-variants)
     * [Gentoo](#gentoo)
     * [OpenSUSE Tumbleweed](#opensuse-tumbleweed)
     * [Ubuntu](#ubuntu)
     * [Debian](#debian)
     * [Guix](#guix)
     * [rde](#rde)
     * [Other](#other)
  * [Sway Usage](#sway-usage)
  * [Run](#run)
  * [Control Center Shortcuts](#control-center-shortcuts)
  * [Configuring](#configuring)
    * [Toggle Buttons](#toggle-buttons)
  * [Notification Inhibition](#notification-inhibition)
  * [Scripting](#scripting)
     * [Disable scripting](#disable-scripting)
  * [i3status-rs Example](#i3status-rs-example)
  * [Waybar Example](#waybar-example)
  * [Debugging Environment Variables](#debugging-environment-variables)

## Want to show off your sick config?

Post your setup here: [Config flex 💪](https://github.com/ErikReider/SwayNotificationCenter/discussions/183)

## Features

- Grouped notifications
- Keyboard shortcuts
- Notification body markup with image support
- Inline replies
- A panel to view previous notifications
- Show album art for notifications like Spotify
- Do not disturb
- Inhibiting notifications through DBUS or client
- Restores previous Do not disturb value after restart
- Click notification to execute default action
- Show alternative notification actions
- Copy detected 2FA codes to clipboard
- Customization through a CSS file
- Trackpad/mouse gesture to close notification
- The same features as any other basic notification daemon
- Basic configuration through a JSON config file
- Hot-reload config through `swaync-client`
- Customizable widgets
- Select the preferred monitor to display on (with swaync-client command for scripting)

## Available Widgets

These widgets can be customized, added, removed and even reordered

- Title
- Do Not Disturb
- Notifications (Will always be visible)
- Label
- Mpris (Media player controls for Spotify, Firefox, Chrome, etc...)
- Menubar with dropdown and buttons
- Button grid
- Volume slider using PulseAudio
- Backlight slider

## Planned Features

- Slick animations 😎

## Install

### Alpine Linux

```zsh
apk add swaync
````

### Arch

```zsh
sudo pacman -S swaync
```

Alternatively, [swaync-git](https://aur.archlinux.org/packages/swaync-git/) is available on the AUR.

### Fedora

The package is available on COPR:

```zsh
dnf copr enable erikreider/SwayNotificationCenter
# Or latest stable release or -git package
dnf install SwayNotificationCenter
dnf install SwayNotificationCenter-git
```

### Fedora Silverblue (and other rpm-ostree variants)

The package can be layered over the base image after adding the Copr repo as an ostree repo:

```zsh
sudo curl -sL -o /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:erikreider:SwayNotificationCenter.repo https://copr.fedorainfracloud.org/coprs/erikreider/SwayNotificationCenter/repo/fedora-$(rpm -E %fedora)/erikreider-SwayNotificationCenter-fedora-$(rpm -E %fedora).repo 
rpm-ostree install SwayNotificationCenter
```

### Gentoo

An **unofficial** ebuild is available in [GURU](https://github.com/gentoo/guru)

```zsh
eselect repository enable guru
emaint sync --repo guru
emerge --ask gui-apps/swaync
```

### OpenSUSE Tumbleweed

```zsh
sudo zypper install SwayNotificationCenter
```

### Ubuntu

Lunar and later:

```zsh
sudo apt install sway-notification-center
```

### Debian

Bookworm and later:

```zsh
sudo apt install sway-notification-center
```

### Guix

The simplest way is to install it to user's profile:

```zsh
guix install swaynotificationcenter
```

But we recommend to use [Guix Home](https://guix.gnu.org/manual/devel/en/html_node/Home-Configuration.html) to manage packages and their configurations declaratively.

### rde

```scm
(use-modules (rde features wm))

;; Include the following code into the list of your rde features:
(feature-swaynotificationcenter)
```

### Other

#### Dependencies

- `vala >= 0.56`
- `meson`
- `blueprint-compiler`
- `git`
- `scdoc`
- `sassc`
- `gtk4`
- `gtk4-layer-shell`
- `dbus`
- `glib2`
- `gobject-introspection`
- `libgee`
- `json-glib`
- `libadwaita`
- `gvfs`
- `granite7`

##### Optional Dependencies

- `libpulse` (requires meson build options change)
- `libnotify`

```zsh
meson setup build --prefix=/usr
ninja -C build
meson install -C build
```

## Sway Usage

```ini
# Notification Daemon
exec swaync

# Toggle control center
bindsym $mod+Shift+n exec swaync-client -t -sw
```

## Run

To start the daemon (remember to kill any other notification daemon before running)

```zsh
./build/src/swaync
```

To toggle the panel

```zsh
./build/src/swaync-client -t
```

To reload the config

```zsh
./build/src/swaync-client -R
```

To reload css after changes

```zsh
./build/src/swaync-client -rs
```

## Control Center Shortcuts

- Up/Down: Navigate notifications
- Home: Navigate to the latest notification
- End: Navigate to the oldest notification
- Escape/Caps_Lock: Close notification panel
- Return: Execute default action or close notification if none
- Delete/BackSpace: Close notification
- Shift+C: Close all notifications
- Shift+D: Toggle Do Not Disturb
- Buttons 1-9: Execute alternative actions
- Left click button / actions: Activate notification action
- Middle/Right click notification: Close notification

## Configuring

The main config file is located in `/etc/xdg/swaync/config.json`. Copy it over
to your `.config/swaync/` folder to customize without needing root access.
See `swaync(5)` man page for more information

To reload the config, you'll need to run `swaync-client --reload-config`

The main CSS style file is located in `/etc/xdg/swaync/style.css`. Copy it over
to your `~/.config/swaync/` folder to customize without needing root access. For
more advanced/larger themes, I recommend that you use the SCSS files from source
and customize them instead. To use the SCSS files, compile with `sassc`.

**Tip**: running swaync with `GTK_DEBUG=interactive swaync` will open a inspector
window that'll allow you to see all of the CSS classes + other information.

## Toggle Buttons

To add toggle buttons to your control center you can set the "type" in any acton to "toggle".
The toggle button supports different commands depending on the state of the button and
an "update-command" to update the state in case of changes from outside swaync. The update-command
is called every time the control center is opened.
The active toggle button also gains the css-class ".toggle:checked"

`config.json` example:

```jsonc
{
  "buttons-grid": { // also works with actions in menubar widget
    "actions": [
      {
        "label": "WiFi",
        "type": "toggle",
        "active": true,
        "command": "sh -c '[[ $SWAYNC_TOGGLE_STATE == true ]] && nmcli radio wifi on || nmcli radio wifi off'",
        "update-command": "sh -c '[[ $(nmcli radio wifi) == \"enabled\" ]] && echo true || echo false'"
      }
    ]
  }
}
```

## Notification Inhibition

Notifications can be inhibited through the provided `swaync-client` executable
or through the DBus interface `org.erikreider.swaync.cc`.

Here's an example of notification inhibition while screen sharing through
`xdg-desktop-portal-wlr`

```conf
# xdg-desktop-portal-wlr config
[screencast]
exec_before=swaync-client --inhibitor-add "xdg-desktop-portal-wlr"
exec_after=swaync-client --inhibitor-remove "xdg-desktop-portal-wlr"
```

## Scripting

Scripting rules and logic:

. <b>Only one</b> script can be fired per notification
. Each script requires `exec` and at least one of the other properties
. All listed properties must match the notification for the script to be ran
. If any of the properties doesn't match, the script will be skipped
. If a notification doesn't include one of the properties, that property will
be skipped
· If a script has `run-on` set to `action`, the script will only run when an
action is taken on the notification

More information can be found in the `swaync(5)` man page

Notification information can be printed into a terminal by running
`G_MESSAGES_DEBUG=all swaync` (when a notification appears).

Config properties:

```jsonc
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
  // other non scripting properties...
}
```

`config.json` example:

```jsonc
{
  "scripts": {
    // This script will only run when Spotify sends a notification containing
    // that exact summary and body
    "example-script": {
      "exec": "/path/to/myRickRollScript.sh",
      "app-name": "Spotify",
      "summary": "Never Gonna Give You Up",
      "body": "Rick Astley - Whenever You Need Somebody"
    }
  }
  // other non scripting properties...
}
```

### Disable scripting

To completely disable scripting, the project needs to be built like so:

```zsh
meson build -Dscripting=false
ninja -C build
meson install -C build
```

## i3status-rs Example

> **Note** Ths requires i3status-rs version 0.31.0+

i3status-rs config

```toml
[[block]]
block = "notify"
format = " $icon {($notification_count.eng(w:1)) |}"
driver = "swaync"
[[block.click]]
button = "left"
action = "show"
[[block.click]]
button = "right"
action = "toggle_paused"
```

## Waybar Example

This example requires `NotoSansMono Nerd Font` to get the icons looking right

Waybar config

```json
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

```css
#custom-notification {
  font-family: "NotoSansMono Nerd Font";
}
```

Alternatively, the number of notifications can be shown by adding `{0}` anywhere in the `format` field in the Waybar config

```jsonc
  "custom/notification": {
    "format": "{0} {icon}",
    // ...
  },
```

## Debugging Environment Variables

- `G_MESSAGES_DEBUG=all`: Displays all of the debug messages.
- `GTK_DEBUG=interactive`: Opens the GTK Inspector.
- `G_ENABLE_DIAGNOSTIC=1`: If set to a non-zero value, this environment variable
  enables diagnostic messages, like deprecation messages for GObject properties
  and signals.
- `G_DEBUG=fatal_criticals` or `G_DEBUG=fatal_warnings`: Causes GLib to abort
  the program at the first call to g_warning() or g_critical().

More can be read [here](https://www.manpagez.com/html/glib/glib-2.56.0/glib-running.php)
