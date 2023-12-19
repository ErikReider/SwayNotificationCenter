namespace SwayNotificationCenter {

    public enum NotificationType { CONTROL_CENTER, POPUP }

    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/notification/notification.ui")]
    public class Notification : Gtk.ListBoxRow {
        [GtkChild]
        unowned Gtk.Revealer revealer;
        [GtkChild]
        unowned Hdy.Carousel carousel;

        [GtkChild]
        unowned Gtk.EventBox event_box;

        [GtkChild]
        unowned Gtk.EventBox default_action;


        /** The default_action gesture. Allows clicks while not in swipe gesture. */
        private Gtk.GestureMultiPress gesture;

        [GtkChild]
        unowned Gtk.ProgressBar progress_bar;

        [GtkChild]
        unowned Gtk.Box base_box;

        [GtkChild]
        unowned Gtk.Revealer close_revealer;
        [GtkChild]
        unowned Gtk.Button close_button;

        private Gtk.ButtonBox ? alt_actions_box = null;

        [GtkChild]
        unowned Gtk.Label summary;
        [GtkChild]
        unowned Gtk.Label time;
        [GtkChild]
        unowned Gtk.Label body;
        [GtkChild]
        unowned Gtk.Image img;
        [GtkChild]
        unowned Gtk.Image img_app_icon;
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

        public static Gtk.IconSize icon_size = Gtk.IconSize.INVALID;
        private int notification_icon_size { get; default = ConfigModel.instance.notification_icon_size; }

        private int notification_body_image_height {
            get;
            default = ConfigModel.instance.notification_body_image_height;
        }
        private int notification_body_image_width {
            get;
            default = ConfigModel.instance.notification_body_image_width;
        }

        private uint timeout_id = 0;

        public bool is_timed { get; construct; default = false; }

        public NotifyParams param { get; private set; }
        public unowned NotiDaemon noti_daemon { get; construct; }

        public NotificationType notification_type {
            get;
            construct;
            default = NotificationType.POPUP;
        }

        public uint timeout_delay { get; construct; }
        public uint timeout_low_delay { get; construct; }
        public uint timeout_critical_delay { get; construct; }

        public int transition_time { get; construct; }

        public int number_of_body_lines { get; construct; default = 10; }

        public bool has_inline_reply { get; private set; default = false; }

        private int carousel_empty_widget_index = 0;

        private static Regex code_regex;

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

        private Notification () {}

        /** Show a non-timed notification */
        public Notification.regular (NotifyParams param,
                                     NotiDaemon noti_daemon,
                                     NotificationType notification_type) {
            Object (noti_daemon: noti_daemon,
                    notification_type: notification_type);
            this.param = param;
            build_noti ();
        }

        /** Show a timed notification */
        public Notification.timed (NotifyParams param,
                                   NotiDaemon noti_daemon,
                                   NotificationType notification_type,
                                   uint timeout,
                                   uint timeout_low,
                                   uint timeout_critical) {
            Object (noti_daemon: noti_daemon,
                    notification_type: notification_type,
                    is_timed: true,
                    timeout_delay: timeout,
                    timeout_low_delay: timeout_low,
                    timeout_critical_delay: timeout_critical,
                    number_of_body_lines: 5
            );
            this.param = param;
            build_noti ();
        }

        construct {
            try {
                code_regex = new Regex ("(?<= |^)(\\d{3}(-| )\\d{3}|\\d{4,8})(?= |$|\\.|,)",
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
            gesture = new Gtk.GestureMultiPress (default_action);
            gesture.set_touch_only (false);
            gesture.set_exclusive (true);
            gesture.set_button (Gdk.BUTTON_PRIMARY);
            gesture.set_propagation_phase (Gtk.PropagationPhase.BUBBLE);
            gesture.pressed.connect ((_gesture, _n_press, _x, _y) => {
                default_action_in = true;
                default_action_down = true;
                default_action_update_state ();
            });
            gesture.released.connect ((gesture, _n_press, _x, _y) => {
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
            gesture.update.connect ((gesture, sequence) => {
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
            gesture.cancel.connect ((_gesture, _sequence) => {
                if (default_action_down) {
                    default_action_down = false;
                    default_action_update_state ();
                }
            });

            this.transition_time = ConfigModel.instance.transition_time;

            ///
            /// Signals
            ///

            this.button_press_event.connect ((event) => {
                if (event.button != Gdk.BUTTON_SECONDARY) return false;
                // Right click
                this.close_notification ();
                return true;
            });

            // Adds CSS :hover selector to EventBox
            default_action.enter_notify_event.connect ((event) => {
                if (event.detail != Gdk.NotifyType.INFERIOR
                    && event.window == default_action.get_window ()) {
                    default_action_in = true;
                    default_action_update_state ();
                }
                return true;
            });
            default_action.leave_notify_event.connect ((event) => {
                if (event.detail != Gdk.NotifyType.INFERIOR
                    && event.window == default_action.get_window ()) {
                    default_action_in = false;
                    default_action_update_state ();
                }
                return true;
            });
            default_action.unmap.connect (() => default_action_in = false);

            close_button.clicked.connect (() => close_notification ());

            this.event_box.enter_notify_event.connect ((event) => {
                close_revealer.set_reveal_child (true);
                remove_noti_timeout ();
                return false;
            });
            this.event_box.leave_notify_event.connect ((event) => {
                if (event.detail == Gdk.NotifyType.INFERIOR) return true;
                close_revealer.set_reveal_child (false);
                add_notification_timeout ();
                return false;
            });

            this.carousel.page_changed.connect ((_, i) => {
                if (i != this.carousel_empty_widget_index) return;
                remove_noti_timeout ();
                try {
                    noti_daemon.manually_close_notification (
                        param.applied_id, false);
                } catch (Error e) {
                    print ("Error: %s\n", e.message);
                    this.destroy ();
                }
            });

            inline_reply_entry.key_release_event.connect ((w, event_key) => {
                switch (Gdk.keyval_name (event_key.keyval)) {
                    case "Return":
                        inline_reply_button.clicked ();
                        return true;
                    default:
                        return false;
                }
            });
            inline_reply_button.clicked.connect (() => {
                string text = inline_reply_entry.get_text ().strip ();
                if (text.length == 0) return;
                noti_daemon.NotificationReplied (param.applied_id, text);
                // Dismiss notification without activating Action
                action_clicked (null);
            });

        }

        private void default_action_update_state () {
            bool pressed = default_action_in && default_action_down;

            Gtk.StateFlags flags = default_action.get_state_flags () &
                                   ~(Gtk.StateFlags.PRELIGHT | Gtk.StateFlags.ACTIVE);

            if (default_action_in) flags |= Gtk.StateFlags.PRELIGHT;
            if (pressed) flags |= Gtk.StateFlags.ACTIVE;

            default_action.set_state_flags (flags, true);
        }

        private void on_size_allocation (Gtk.Allocation _ignored) {
            // Force recomputing the allocated size of the wrapped GTK label in the body.
            // `queue_resize` alone DOES NOT WORK because it does not properly invalidate
            // the cache, this is a GTK bug!
            // See https://gitlab.gnome.org/GNOME/gtk/-/issues/2556
            if (body != null) {
                body.set_size_request (-1, body.get_allocated_height ());
            }
        }

        private void build_noti () {
            this.body.set_line_wrap (true);
            this.body.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
            this.body.set_ellipsize (Pango.EllipsizeMode.END);

            this.summary.set_line_wrap (false);
            this.summary.set_text (param.summary ?? param.app_name);
            this.summary.set_ellipsize (Pango.EllipsizeMode.END);

            close_revealer.set_transition_duration (this.transition_time);

            this.revealer.set_transition_duration (this.transition_time);

            this.carousel.set_animation_duration (this.transition_time);
            // Changes the swipe direction depending on the notifications X position
            switch (ConfigModel.instance.positionX) {
                case PositionX.LEFT:
                    this.carousel.reorder (event_box, 0);
                    this.carousel_empty_widget_index = 1;
                    break;
                default:
                case PositionX.RIGHT:
                case PositionX.CENTER:
                    this.carousel.scroll_to (event_box);
                    this.carousel_empty_widget_index = 0;
                    break;
            }
            // Reset state
            this.carousel.scroll_to (event_box);
            this.carousel.allow_scroll_wheel = false;

            if (this.progress_bar.visible = param.has_synch) {
                this.progress_bar.set_fraction (param.value * 0.01);
            }

            set_body ();
            set_icon ();
            set_inline_reply ();
            set_actions ();
            set_style_urgency ();

            this.show ();

            Timeout.add (0, () => {
                this.revealer.set_reveal_child (true);
                return Source.REMOVE;
            });

            remove_noti_timeout ();
            this.size_allocate.disconnect (on_size_allocation);
            if (is_timed) {
                add_notification_timeout ();
                this.size_allocate.connect (on_size_allocation);
            }
        }

        private void set_body () {
            string text = param.body ?? "";

            this.body.set_lines (this.number_of_body_lines);

            // Reset state
            this.body_image.hide ();

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
                Pango.AttrList ? attr = null;
                string ? buf = null;
                try {
                    // Try parsing without any hacks
                    Pango.parse_markup (text, -1, 0, out attr, out buf, null);
                } catch (Error e) {
                    // Default to hack if the initial markup couldn't be parsed

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

                    // Turns it back to markup, defaults to original if not valid
                    Pango.parse_markup (escaped, -1, 0, out attr, out buf, null);
                }

                this.body.set_text (buf);
                if (attr != null) this.body.set_attributes (attr);
            } catch (Error e) {
                stderr.printf ("Could not parse Pango markup %s: %s\n",
                               text, e.message);
                // Sets the original text
                this.body.set_text (text);
            }
        }

        /** Returns the first code found, else null */
        private string ? parse_body_codes () {
            if (!ConfigModel.instance.notification_2fa_action) return null;
            string body = this.body.get_text ().strip ();
            if (body.length == 0) return null;

            MatchInfo info;
            var result = code_regex.match (body, RegexMatchFlags.NOTEMPTY, out info);
            string ? match = info.fetch (0);
            if (!result || match == null) return null;

            return Functions.filter_string (
                match.strip (), (c) => c.isdigit () || c.isspace ()).strip ();
        }

        public void click_default_action () {
            action_clicked (param.default_action, true);
        }

        public void click_alt_action (uint index) {
            if (alt_actions_box == null) return;
            List<weak Gtk.Widget> ? children = alt_actions_box.get_children ();
            uint length = children.length ();
            if (length == 0 || index >= length) return;

            unowned Gtk.Widget button = children.nth_data (index);
            if (button is Gtk.Button) {
                ((Gtk.Button) button).clicked ();
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
                        print ("Error: %s\n", e.message);
                    }
                }
            }
            if (!param.resident) close_notification ();
        }

        private void set_style_urgency () {
            // Reset state
            base_box.get_style_context ().remove_class ("low");
            base_box.get_style_context ().remove_class ("normal");
            base_box.get_style_context ().remove_class ("critical");

            switch (param.urgency) {
                case UrgencyLevels.LOW:
                    base_box.get_style_context ().add_class ("low");
                    break;
                case UrgencyLevels.NORMAL:
                default:
                    base_box.get_style_context ().add_class ("normal");
                    break;
                case UrgencyLevels.CRITICAL:
                    base_box.get_style_context ().add_class ("critical");
                    break;
            }
        }

        private void set_inline_reply () {
            // Reset state
            inline_reply_box.hide ();
            // Only show inline replies in popup notifications if the compositor
            // supports ON_DEMAND layer shell keyboard interactivity
            if (!ConfigModel.instance.notification_inline_replies
                || (ConfigModel.instance.layer_shell
                   && layer_shell_protocol_version < 4
                   && notification_type == NotificationType.POPUP)) {
                return;
            }
            if (param.inline_reply == null) return;

            has_inline_reply = true;

            inline_reply_box.show ();

            inline_reply_entry.set_placeholder_text (
                param.inline_reply_placeholder ?? "Enter Text");
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

            inline_reply_button.set_label (param.inline_reply.name ?? "Reply");
        }

        private void set_actions () {
            // Reset state
            foreach (Gtk.Widget child in base_box.get_children ()) {
                if (child is Gtk.ScrolledWindow) {
                    child.destroy ();
                }
            }

            // Check for security codes
            string ? code = parse_body_codes ();
            if (param.actions.length > 0 || code != null) {
                var viewport = new Gtk.Viewport (null, null);
                var scroll = new Gtk.ScrolledWindow (null, null);
                alt_actions_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
                alt_actions_box.set_homogeneous (true);
                alt_actions_box.set_layout (Gtk.ButtonBoxStyle.EXPAND);

                // Add "Copy code" Action if available and copy it to clipboard when clicked
                if (code != null && code.length > 0) {
                    string action_name = "COPY \"%s\"".printf (code);
                    var action_button = new Gtk.Button.with_label (action_name);
                    action_button.clicked.connect (() => {
                        // Copy to clipboard
                        get_clipboard (Gdk.SELECTION_CLIPBOARD).set_text (code, -1);
                        // Dismiss notification
                        action_clicked (null);
                    });
                    action_button
                     .get_style_context ().add_class ("notification-action");
                    action_button.set_can_focus (false);
                    alt_actions_box.add (action_button);
                }

                // Add notification specified actions
                foreach (var action in param.actions.data) {
                    var action_button = new Gtk.Button.with_label (action.name);
                    action_button.clicked.connect (() => action_clicked (action));
                    action_button
                     .get_style_context ().add_class ("notification-action");
                    action_button.set_can_focus (false);
                    alt_actions_box.add (action_button);
                }
                viewport.add (alt_actions_box);
                scroll.add (viewport);
                base_box.add (scroll);
                scroll.show_all ();
            }
        }

        public void set_time () {
            if (ConfigModel.instance.relative_timestamps) {
                this.time.set_text (get_relative_time ());
            } else {
                this.time.set_text (get_iso8601_time ());
            }
        }

        private string get_relative_time () {
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

        private string get_iso8601_time () {
            var dtime = new DateTime.from_unix_local (param.time);
            return dtime.format_iso8601 ();
        }

        public void close_notification (bool is_timeout = false) {
            remove_noti_timeout ();
            this.revealer.set_reveal_child (false);
            Timeout.add (this.transition_time, () => {
                try {
                    noti_daemon.manually_close_notification (param.applied_id,
                                                             is_timeout);
                } catch (Error e) {
                    print ("Error: %s\n", e.message);
                    this.destroy ();
                }
                return Source.REMOVE;
            });
        }

        public void replace_notification (NotifyParams new_params) {
            this.param = new_params;
            build_noti ();
        }

        private void set_icon () {
            img.clear ();
            img.set_visible (true);
            img_app_icon.clear ();
            img_app_icon.set_visible (true);

            Icon ? app_icon_name = null;
            string ? app_icon_uri = null;
            if (param.desktop_app_info != null) {
                app_icon_name = param.desktop_app_info.get_icon ();
            }
            if (param.app_icon != null && param.app_icon != "") {
                app_icon_uri = param.app_icon;
            }

            var image_visibility = ConfigModel.instance.image_visibility;
            if (image_visibility == ImageVisibility.NEVER) {
                img.set_visible (false);
                img_app_icon.set_visible (false);
                return;
            }

            img.set_pixel_size (notification_icon_size);
            img.height_request = notification_icon_size;
            img.width_request = notification_icon_size;
            int app_icon_size = notification_icon_size / 3;
            img_app_icon.set_pixel_size (app_icon_size);

            var img_path_exists = File.new_for_uri (
                param.image_path ?? "").query_exists ();
            var app_icon_exists = File.new_for_uri (
                app_icon_uri ?? "").query_exists ();

            // Get the image CSS corner radius in pixels
            int radius = 0;
            unowned var ctx = img.get_style_context ();
            var value = ctx.get_property (Gtk.STYLE_PROPERTY_BORDER_RADIUS,
                                          ctx.get_state ());
            if (value.type () == Type.INT) {
                radius = value.get_int ();
            }

            // Set the main image to the provided image
            if (param.image_data.is_initialized) {
                Functions.set_image_data (param.image_data, img,
                                          notification_icon_size, radius);
            } else if (param.image_path != null &&
                       param.image_path != "" &&
                       img_path_exists) {
                Functions.set_image_uri (param.image_path, img,
                                          notification_icon_size,
                                          radius,
                                          img_path_exists);
            } else if (param.icon_data.is_initialized) {
                Functions.set_image_data (param.icon_data, img,
                                          notification_icon_size, radius);
            }

            if (img.storage_type == Gtk.ImageType.EMPTY) {
                // Get the app icon
                if (app_icon_uri != null) {
                    Functions.set_image_uri (app_icon_uri, img,
                                              notification_icon_size,
                                              radius,
                                              app_icon_exists);
                } else if (app_icon_name != null) {
                    img.set_from_gicon (app_icon_name, icon_size);
                } else if (image_visibility == ImageVisibility.ALWAYS) {
                    // Default icon
                    img.set_from_icon_name ("image-missing", icon_size);
                } else {
                    img.set_visible (false);
                }
            } else {
                // We only set the app icon if the main image is set
                if (app_icon_uri != null) {
                    Functions.set_image_uri (app_icon_uri, img_app_icon,
                                             app_icon_size,
                                             0,
                                             app_icon_exists);
                } else if (app_icon_name != null) {
                    img_app_icon.set_from_gicon (app_icon_name, Gtk.IconSize.INVALID);
                }
            }
        }

        public void add_notification_timeout () {
            if (!this.is_timed) return;

            // Removes the previous timeout
            remove_noti_timeout ();

            uint timeout;
            switch (param.urgency) {
                case UrgencyLevels.LOW:
                    timeout = timeout_low_delay * 1000;
                    break;
                case UrgencyLevels.NORMAL:
                default:
                    timeout = timeout_delay * 1000;
                    break;
                case UrgencyLevels.CRITICAL:
                    // Critical notifications should not automatically expire.
                    // Ignores the notifications expire_timeout.
                    if (timeout_critical_delay == 0) return;
                    timeout = timeout_critical_delay * 1000;
                    break;
            }
            uint ms = param.expire_timeout > 0 ? param.expire_timeout : timeout;
            if (ms <= 0) return;
            timeout_id = Timeout.add (ms, () => {
                close_notification (true);
                return Source.REMOVE;
            });
        }

        public void remove_noti_timeout () {
            if (timeout_id > 0) {
                Source.remove (timeout_id);
                timeout_id = 0;
            }
        }

        /** Forces the EventBox to reload its style_context #27 */
        public void reload_style_context () {
            event_box.get_style_context ().changed ();
            default_action.get_style_context ().changed ();
        }
    }
}
