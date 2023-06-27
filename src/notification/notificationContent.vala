namespace SwayNotificationCenter {
    [GtkTemplate (ui = "/org/erikreider/swaync/templates/notificationContent.ui")]
    public class NotificationContent : Adw.Bin {
        [GtkChild]
        unowned Gtk.Overlay overlay;

        [GtkChild]
        unowned Gtk.Box default_action;


        /** The default_action gesture. Allows clicks while not in swipe gesture. */
        public Gtk.EventControllerFocus focus_event = new Gtk.EventControllerFocus ();
        private Gtk.EventControllerMotion motion_event = new Gtk.EventControllerMotion ();
        private Gtk.GestureClick secondary_gesture_click = new Gtk.GestureClick ();
        private Gtk.GestureClick default_action_gesture_click = new Gtk.GestureClick ();
        private Gtk.EventControllerKey inline_reply_key_event = new Gtk.EventControllerKey ();

        [GtkChild]
        unowned Gtk.ProgressBar progress_bar;
        // TODO: REPLACE WITH Gtk.LevelBar

        [GtkChild]
        unowned Gtk.Box base_box;

        [GtkChild]
        unowned Gtk.Revealer close_revealer;
        [GtkChild]
        unowned Gtk.Button close_button;

        private IterBox alt_actions_box = new IterBox (Gtk.Orientation.HORIZONTAL, 0);

        [GtkChild]
        unowned Gtk.Label summary_label;
        [GtkChild]
        unowned Gtk.Label time_label;
        [GtkChild]
        unowned Gtk.Label body_label;
        [GtkChild]
        unowned Gtk.Image img;
        [GtkChild]
        unowned Gtk.Image body_image;

        // Inline Reply
        [GtkChild]
        unowned Gtk.Box inline_reply_box;
        [GtkChild]
        unowned Gtk.Entry inline_reply_entry;
        [GtkChild]
        unowned Gtk.Button inline_reply_button;

        private bool default_action_down = false;
        private bool default_action_in = false;

        private int notification_body_image_height {
            get;
            default = ConfigModel.instance.notification_body_image_height;
        }
        private int notification_body_image_width {
            get;
            default = ConfigModel.instance.notification_body_image_width;
        }

        public unowned Notification notification { get; construct; }
        public unowned NotifyParams param {
            get { return notification.param; }
        }
        public unowned NotiDaemon noti_daemon {
            get { return notification.noti_daemon; }
        }

        public bool has_inline_reply { get; private set; default = false; }

        public int number_of_body_lines { get; construct; }

        public bool is_constructed { get; private set; default = false; }

        private static Regex code_2fa_regex;
        private static Regex tag_regex;
        private static Regex tag_unescape_regex;
        private static Regex img_tag_regex;
        private const string[] TAGS = { "b", "u", "i" };
        private const string[] UNESCAPE_CHARS = {
            "lt;", "#60;", "#x3C;", "#x3c;", // <
            "gt;", "#62;", "#x3E;", "#x3e;", // >
            "apos;", "#39;", // '
            "quot;", "#34;", // "
            "amp;" // &
        };

        construct {
            hexpand = true;
            vexpand = true;

            try {
                code_2fa_regex = new Regex ("(?<= |^)(\\d{3}(-| )\\d{3}|\\d{4,7})(?= |$|\\.|,)",
                                            RegexCompileFlags.MULTILINE);
                string joined_tags = string.joinv ("|", TAGS);
                tag_regex = new Regex ("&lt;(/?(?:%s))&gt;".printf (joined_tags));
                string unescaped = string.joinv ("|", UNESCAPE_CHARS);
                tag_unescape_regex = new Regex ("&amp;(?=%s)".printf (unescaped));
                img_tag_regex = new Regex ("""<img[^>]* src=\"([^\"]*)\"[^>]*>""");
            } catch (Error e) {
                stderr.printf ("Invalid regex: %s", e.message);
            }

            // Build the default_action gesture. Makes clickes compatible with
            // the Hdy Swipe gesture unlike a regular ::button_release_event
            default_action.add_controller (default_action_gesture_click);
            default_action_gesture_click.set_touch_only (false);
            default_action_gesture_click.set_button (Gdk.BUTTON_PRIMARY);
            default_action_gesture_click.pressed.connect ((_gesture, _n_press, _x, _y) => {
                default_action_in = true;
                default_action_down = true;
                default_action_update_state ();
            });
            default_action_gesture_click.released.connect ((gesture, _n_press, _x, _y) => {
                // Emit released
                if (!default_action_down) return;
                default_action_down = false;
                if (default_action_in) {
                    click_default_action ();
                }

                Gdk.EventSequence ? sequence = gesture.get_current_sequence ();
                if (sequence == null) {
                    default_action_in = false;
                    default_action_update_state ();
                }
            });
            default_action_gesture_click.update.connect ((gesture, sequence) => {
                Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
                if (sequence != gesture_single.get_current_sequence ()) return;

                Gtk.Allocation allocation;
                double x, y;
            
                default_action.get_allocation (out allocation);
                gesture.get_point (sequence, out x, out y);
                bool in_button = (x >= 0 && y >= 0 && x < allocation.width && y < allocation.height);
                if (default_action_in != in_button) {
                    default_action_in = in_button;
                    default_action_update_state ();
                }
            });
            default_action_gesture_click.cancel.connect ((_gesture, _sequence) => {
                if (default_action_down) {
                    default_action_down = false;
                    default_action_update_state ();
                }
            });

            // Right click to close
            add_controller (secondary_gesture_click);
            secondary_gesture_click.set_touch_only (false);
            secondary_gesture_click.set_exclusive (false);
            secondary_gesture_click.set_button (Gdk.BUTTON_SECONDARY);
            secondary_gesture_click.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            secondary_gesture_click.released.connect ((controller, n, x, y) => {
                var event = (Gdk.ButtonEvent) controller.get_current_event ();
                if (event.get_button () == Gdk.BUTTON_SECONDARY) {
                   notification.close_notification ();
                }
            });
        }

        public NotificationContent (Notification notification) {
            bool is_popup = notification.notification_type == NotificationType.POPUP;
            Object (
                notification: notification,
                number_of_body_lines: (is_popup ? 5 : 10)
            );

            default_action.unmap.connect (() => default_action_in = false);

            close_button.clicked.connect (() => {
                notification.close_notification ();
            });

            add_controller (motion_event);
            motion_event.enter.connect ((event) => {
                close_revealer.set_reveal_child (true);
                notification.remove_noti_timeout ();
            });

            motion_event.leave.connect ((event) => {
                // if (event.detail == Gdk.NotifyType.INFERIOR) return true;
                close_revealer.set_reveal_child (false);
                notification.add_notification_timeout ();
            });
        }

        public void refresh_body_height () {
            body_label.set_size_request (-1, body_label.get_allocated_height ());
        }

        private void default_action_update_state () {
            bool pressed = default_action_in && default_action_down;

            Gtk.StateFlags flags = default_action.get_state_flags () &
                                   ~(Gtk.StateFlags.PRELIGHT | Gtk.StateFlags.ACTIVE);

            if (default_action_in) flags |= Gtk.StateFlags.PRELIGHT;
            if (pressed) flags |= Gtk.StateFlags.ACTIVE;

            default_action.set_state_flags (flags, true);
        }

        public void build_notification () {
            if (is_constructed) return;

            overlay.add_overlay (close_revealer);

            this.body_label.set_wrap (true);
            this.body_label.set_wrap_mode (Pango.WrapMode.WORD_CHAR);
            this.body_label.set_ellipsize (Pango.EllipsizeMode.END);

            this.summary_label.set_wrap (false);
            this.summary_label.set_text (param.summary ?? param.app_name);
            this.summary_label.set_ellipsize (Pango.EllipsizeMode.END);

            close_revealer.set_transition_duration (notification.transition_time);

            if (this.progress_bar.visible = param.has_synch) {
                this.progress_bar.set_fraction (param.value * 0.01);
            }

            this.body_image.set_visible (false);
            this.inline_reply_box.set_visible (false);

            set_body ();
            set_icon ();
            set_inline_reply ();
            set_actions ();
            set_style_urgency ();

            is_constructed = true;
        }

        /*
         * Widgets
         */

        private void set_body () {
            string text = param.body ?? "";

            this.body_label.set_lines (this.number_of_body_lines);

            // Removes all image tags and adds them to an array
            if (text.length > 0) {
                try {
                    // Get src paths from images
                    string[] img_paths = {};
                    MatchInfo info;
                    if (img_tag_regex.match (text, 0, out info)) {
                        img_paths += Functions.get_match_from_info (info);
                        while (info.next ()) {
                            img_paths += Functions.get_match_from_info (info);
                        }
                    }

                    // Remove all images
                    text = img_tag_regex.replace (text, text.length, 0, "");

                    // Set the image if exists and is valid
                    if (img_paths.length > 0) {
                        var img = img_paths[0];
                        var file = File.new_for_path (img);
                        if (img.length > 0 && file.query_exists ()) {
                            var buf = new Gdk.Pixbuf.from_file_at_scale (
                                file.get_path (),
                                notification_body_image_width,
                                notification_body_image_height,
                                true);
                            this.body_image.set_from_pixbuf (buf);
                            this.body_image.show ();
                        }
                    }
                } catch (Error e) {
                    stderr.printf (e.message);
                }
            }

            // Markup
            try {
                // Escapes all characters
                string escaped = Markup.escape_text (text);
                // Replace all valid tags brackets with <,</,> so that the
                // markup parser only parses valid tags
                // Ex: &lt;b&gt;BOLD&lt;/b&gt; -> <b>BOLD</b>
                escaped = tag_regex.replace (escaped, escaped.length, 0, "<\\1>");

                // Unescape a few characters that may have been double escaped
                // Sending "<" in Discord would result in "&amp;lt;" without this
                // &amp;lt; -> &lt;
                escaped = tag_unescape_regex.replace_literal (escaped, escaped.length, 0, "&");

                // Turns it back to markdown, defaults to original if not valid
                Pango.AttrList ? attr = null;
                string ? buf = null;
                Pango.parse_markup (escaped, -1, 0, out attr, out buf, null);

                this.body_label.set_text (buf);
                if (attr != null) this.body_label.set_attributes (attr);
            } catch (Error e) {
                stderr.printf ("Could not parse Pango markup %s: %s\n",
                               text, e.message);
                // Sets the original text
                this.body_label.set_text (text);
            }
        }

        /** Returns the first code found, else null */
        private string ? parse_body_codes () {
            if (!ConfigModel.instance.notification_2fa_action) return null;
            string body = this.body_label.get_text ().strip ();
            if (body.length == 0) return null;

            MatchInfo info;
            var result = code_2fa_regex.match (body, RegexMatchFlags.NOTEMPTY, out info);
            string ? match = info.fetch (0);
            if (!result || match == null) return null;

            return Functions.filter_string (
                match.strip (), (c) => c.isdigit () || c.isspace ()).strip ();
        }

        public void click_default_action () {
            action_clicked (param.default_action, true);
        }

        public void click_alt_action (uint index) {
            List<weak Gtk.Widget> ? children = alt_actions_box.get_children ();
            if (alt_actions_box.length == 0 || index >= alt_actions_box.length) return;

            unowned Gtk.Widget button = children.nth_data (index);
            if (button is Gtk.Button) {
                button.clicked ();
                return;
            }
            // Backup if the above fails
            action_clicked (param.actions.index (index));
        }

        private void action_clicked (Action ? action, bool is_default = false) {
            noti_daemon.run_scripts (param, ScriptRunOnType.ACTION);
            if (action != null
                && action.identifier != null
                && action.identifier != "") {
                noti_daemon.ActionInvoked (param.applied_id, action.identifier);
                if (ConfigModel.instance.hide_on_action) {
                    try {
                        swaync_daemon.set_visibility (false);
                    } catch (Error e) {
                        printerr ("Error: %s\n", e.message);
                    }
                }
            }
            if (!param.resident) notification.close_notification ();
        }

        private void set_style_urgency () {
            switch (param.urgency) {
                case UrgencyLevels.LOW:
                    base_box.add_css_class ("low");
                    break;
                case UrgencyLevels.NORMAL:
                default:
                    base_box.add_css_class ("normal");
                    break;
                case UrgencyLevels.CRITICAL:
                    base_box.add_css_class ("critical");
                    break;
            }
        }

        private void set_inline_reply () {
            // Only show inline replies in popup notifications if the compositor
            // supports ON_DEMAND layer shell keyboard interactivity
            if (!ConfigModel.instance.notification_inline_replies
                || (ConfigModel.instance.layer_shell
                   && layer_shell_protocol_version < 4
                   && notification.notification_type == NotificationType.POPUP)) {
                return;
            }
            if (notification.param.inline_reply == null) return;

            has_inline_reply = true;

            inline_reply_box.show ();

            inline_reply_entry.set_placeholder_text (
                notification.param.inline_reply_placeholder ?? "Enter Text");
            // Set reply Button sensitivity to disabled if Entry text is empty
            inline_reply_entry.bind_property (
                "text",
                inline_reply_button, "sensitive",
                BindingFlags.SYNC_CREATE,
                (binding, srcval, ref targetval) => {
                    targetval.set_boolean (((string) srcval).strip ().length > 0);
                    return true;
                },
                null);

            inline_reply_entry.add_controller (inline_reply_key_event);
            inline_reply_key_event.key_released.connect ((keyval, keycode, state) => {
                switch (Gdk.keyval_name (keyval)) {
                    case "Return":
                        inline_reply_button.clicked ();
                        break;
                    default:
                        break;
                }
            });

            inline_reply_button.set_label (param.inline_reply.name ?? "Reply");
            inline_reply_button.clicked.connect (() => {
                string text = inline_reply_entry.get_text ().strip ();
                if (text.length == 0) return;
                noti_daemon.NotificationReplied (param.applied_id, text);
                // Dismiss notification without activating Action
                action_clicked (null);
            });
        }

        private void set_actions () {
            // Check for security codes
            string ? code = parse_body_codes ();
            if (param.actions.length > 0 || code != null) {
                var viewport = new Gtk.Viewport (null, null);
                var scroll = new Gtk.ScrolledWindow ();
                alt_actions_box.set_homogeneous (true);
                // alt_actions_box.set_layout (Gtk.ButtonBoxStyle.EXPAND);

                // Add "Copy code" Action if available and copy it to clipboard when clicked
                if (code != null && code.length > 0) {
                    string action_name = "COPY \"%s\"".printf (code);
                    var action_button = new Gtk.Button.with_label (action_name);
                    action_button.clicked.connect (() => {
                        // Copy to clipboard
                        get_clipboard ().set_text (code);
                        // Dismiss notification
                        action_clicked (null);
                    });
                    action_button.add_css_class ("notification-action");
                    action_button.set_can_focus (false);
                    alt_actions_box.append (action_button);
                }

                // Add notification specified actions
                foreach (var action in param.actions.data) {
                    var action_button = new Gtk.Button.with_label (action.name);
                    action_button.clicked.connect (() => action_clicked (action));
                    action_button.add_css_class ("notification-action");
                    action_button.set_can_focus (false);
                    alt_actions_box.append (action_button);
                }
                viewport.set_child (alt_actions_box);
                scroll.set_child (viewport);
                base_box.append (scroll);
            }
        }

        public void set_time () {
            this.time_label.set_text (get_readable_time ());
        }

        private string get_readable_time () {
            string value = "";

            double diff = (get_real_time () * 0.000001) - param.time;
            double secs = diff / 60;
            double hours = secs / 60;
            double days = hours / 24;
            if (secs < 1) {
                value = "Now";
            } else if (secs >= 1 && hours < 1) {
                // 1m - 1h
                var val = Math.floor (secs);
                value = val.to_string () + " min";
                if (val > 1) value += "s";
                value += " ago";
            } else if (hours >= 1 && hours < 24) {
                // 1h - 24h
                var val = Math.floor (hours);
                value = val.to_string () + " hour";
                if (val > 1) value += "s";
                value += " ago";
            } else {
                // Days
                var val = Math.floor (days);
                value = val.to_string () + " day";
                if (val > 1) value += "s";
                value += " ago";
            }
            return value;
        }

        private void set_icon () {
            var image_visibility = ConfigModel.instance.image_visibility;
            if (image_visibility == ImageVisibility.NEVER) {
                img.set_visible (false);
                return;
            }

            img.set_pixel_size (ConfigModel.instance.notification_icon_size);
            img.height_request = img.pixel_size;
            img.width_request = img.pixel_size;

            var img_path_exists = File.new_for_path (
                param.image_path ?? "").query_exists ();
            var app_icon_exists = File.new_for_path (
                param.app_icon ?? "").query_exists ();

            if (param.image_data.is_initialized) {
                Functions.set_image_data (param.image_data, img);
            } else if (param.image_path != null &&
                       param.image_path != "" &&
                       img_path_exists) {
                Functions.set_image_path (param.image_path, img, img_path_exists);
            } else if (param.app_icon != null && param.app_icon != "") {
                Functions.set_image_path (param.app_icon, img, app_icon_exists);
            } else if (param.icon_data.is_initialized) {
                Functions.set_image_data (param.icon_data, img);
            } else {
                // Get the app icon
                Icon ? icon = null;
                if (param.desktop_entry != null) {
                    string entry = param.desktop_entry;
                    entry = entry.replace (".desktop", "");
                    DesktopAppInfo entry_info = new DesktopAppInfo (
                        "%s.desktop".printf (entry));
                    // Checks if the .desktop file actually exists or not
                    if (entry_info is DesktopAppInfo) {
                        icon = entry_info.get_icon ();
                    }
                }
                // TODO: Make sure that pixel size is used
                if (icon != null) {
                    img.set_from_gicon (icon);
                } else if (image_visibility == ImageVisibility.ALWAYS) {
                    // Default icon
                    img.set_from_icon_name ("image-missing");
                } else {
                    img.set_visible (false);
                }
            }
        }
    }
}
