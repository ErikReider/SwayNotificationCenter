namespace SwayNotificationCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/notification/notification.ui")]
    private class Notification : Gtk.ListBoxRow {
        [GtkChild]
        unowned Gtk.Revealer revealer;
        [GtkChild]
        unowned Hdy.Carousel carousel;

        [GtkChild]
        unowned Gtk.EventBox event_box;

        [GtkChild]
        unowned Gtk.Button default_button;

        [GtkChild]
        unowned Gtk.ProgressBar progress_bar;

        [GtkChild]
        unowned Gtk.Box base_box;

        [GtkChild]
        unowned Gtk.Revealer close_revealer;
        [GtkChild]
        unowned Gtk.Button close_button;

        private Gtk.ButtonBox alt_actions_box;

        [GtkChild]
        unowned Gtk.Label summary;
        [GtkChild]
        unowned Gtk.Label time;
        [GtkChild]
        unowned Gtk.Label body;
        [GtkChild]
        unowned Gtk.Image img;
        [GtkChild]
        unowned Gtk.Image body_image;

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

        public NotifyParams param { get; construct; }
        public NotiDaemon noti_daemon { get; construct; }

        public uint timeout_delay { get; construct; }
        public uint timeout_low_delay { get; construct; }
        public uint timeout_critical_delay { get; construct; }

        public int transition_time { get; construct; }

        public int number_of_body_lines { get; construct; default = 10; }

        private int carousel_empty_widget_index = 0;

        private static Regex tag_regex;
        private static Regex tag_unescape_regex;
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
                                     NotiDaemon noti_daemon) {
            Object (noti_daemon: noti_daemon, param: param);
        }

        /** Show a timed notification */
        public Notification.timed (NotifyParams param,
                                   NotiDaemon noti_daemon,
                                   uint timeout,
                                   uint timeout_low,
                                   uint timeout_critical) {
            Object (noti_daemon: noti_daemon,
                    param: param,
                    is_timed: true,
                    timeout_delay: timeout,
                    timeout_low_delay: timeout_low,
                    timeout_critical_delay: timeout_critical,
                    number_of_body_lines: 5
            );
        }

        construct {
            try {
                string joined_tags = string.joinv ("|", TAGS);
                tag_regex = new Regex ("&lt;(/?(?:%s))&gt;".printf (joined_tags));
                string unescaped = string.joinv ("|", UNESCAPE_CHARS);
                tag_unescape_regex = new Regex ("&amp;(?=%s)".printf (unescaped));
            } catch (Error e) {
                stderr.printf ("Invalid regex: %s", e.message);
            }

            this.transition_time = ConfigModel.instance.transition_time;
            build_noti ();

            if (is_timed) {
                add_notification_timeout ();
                this.size_allocate.connect (on_size_allocation);
            }
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

            this.button_press_event.connect ((event) => {
                if (event.button != Gdk.BUTTON_SECONDARY) return false;
                // Right click
                this.close_notification ();
                return true;
            });

            default_button.clicked.connect (click_default_action);

            close_revealer.set_transition_duration (this.transition_time);

            close_button.clicked.connect (() => close_notification ());

            this.event_box.enter_notify_event.connect (() => {
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

            this.revealer.set_transition_duration (this.transition_time);

            this.carousel.set_animation_duration (this.transition_time);
            // Changes the swipte direction depending on the notifications X position
            switch (ConfigModel.instance.positionX) {
                case PositionX.LEFT:
                    this.carousel.reorder (event_box, 0);
                    this.carousel_empty_widget_index = 1;
                    break;
                case PositionX.RIGHT:
                case PositionX.CENTER:
                    this.carousel.scroll_to (event_box);
                    this.carousel_empty_widget_index = 0;
                    break;
            }
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
#if HAVE_LATEST_LIBHANDY
            this.carousel.allow_scroll_wheel = false;
#endif

            if (this.progress_bar.visible = param.has_synch) {
                this.progress_bar.set_fraction (param.value * 0.01);
            }

            set_body ();
            set_icon ();
            set_actions ();
            set_style_urgency ();

            this.show ();

            if (param.replaces) {
                this.revealer.set_reveal_child (true);
            } else {
                Timeout.add (0, () => {
                    this.revealer.set_reveal_child (true);
                    return Source.REMOVE;
                });
            }
        }

        private void set_body () {
            string text = param.body ?? "";

            this.body.set_lines (this.number_of_body_lines);

            // Removes all image tags and adds them to an array
            if (text.length > 0) {
                try {
                    Regex img_exp = new Regex (
                        """<img[^>]* src=\"([^\"]*)\"[^>]*>""",
                        RegexCompileFlags.JAVASCRIPT_COMPAT);

                    // Get src paths from images
                    string[] img_paths = {};
                    MatchInfo info;
                    if (img_exp.match (text, 0, out info)) {
                        img_paths += Functions.get_match_from_info (info);
                        while (info.next ()) {
                            img_paths += Functions.get_match_from_info (info);
                        }
                    }

                    // Remove all images
                    text = img_exp.replace (text, text.length, 0, "");

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

                this.body.set_text (buf);
                if (attr != null) this.body.set_attributes (attr);
            } catch (Error e) {
                stderr.printf ("Could not parse Pango markup %s: %s\n",
                               text, e.message);
                // Sets the original text
                this.body.set_text (text);
            }
        }

        public void click_default_action () {
            action_clicked (param.default_action, true);
        }

        public void click_alt_action (uint index) {
            if (param.actions.length == 0 || index >= param.actions.length) {
                return;
            }
            action_clicked (param.actions.index (index));
        }

        private void action_clicked (Action ? action, bool is_default = false) {
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

        private void set_actions () {
            if (param.actions.length > 0) {
                var viewport = new Gtk.Viewport (null, null);
                var scroll = new Gtk.ScrolledWindow (null, null);
                alt_actions_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
                alt_actions_box.set_homogeneous (true);
                alt_actions_box.set_layout (Gtk.ButtonBoxStyle.EXPAND);
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
            this.time.set_text (get_readable_time ());
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

        private void set_icon () {
            var image_visibility = ConfigModel.instance.image_visibility;
            if (image_visibility == ImageVisibility.NEVER) {
                img.set_visible (false);
                return;
            }

            img.set_pixel_size (notification_icon_size);
            img.height_request = notification_icon_size;
            img.width_request = notification_icon_size;

            var img_path_exists = File.new_for_path (
                param.image_path ?? "").query_exists ();
            var app_icon_exists = File.new_for_path (
                param.app_icon ?? "").query_exists ();

            if (param.image_data.is_initialized) {
                Functions.set_image_data (param.image_data, img,
                                          notification_icon_size);
            } else if (param.image_path != null &&
                       param.image_path != "" &&
                       img_path_exists) {
                Functions.set_image_path (param.image_path, img,
                                          notification_icon_size,
                                          img_path_exists);
            } else if (param.app_icon != null && param.app_icon != "") {
                Functions.set_image_path (param.app_icon, img,
                                          notification_icon_size,
                                          app_icon_exists);
            } else if (param.icon_data.is_initialized) {
                Functions.set_image_data (param.icon_data, img,
                                          notification_icon_size);
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
                if (icon != null) {
                    img.set_from_gicon (icon, icon_size);
                } else if (image_visibility == ImageVisibility.ALWAYS) {
                    // Default icon
                    img.set_from_icon_name ("image-missing", icon_size);
                } else {
                    img.set_visible (false);
                }
            }
        }

        public void add_notification_timeout () {
            if (!this.is_timed) return;

            // Removes the previous timeout
            remove_noti_timeout ();

            uint timeout;
            switch (param.urgency) {
                case UrgencyLevels.LOW :
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
        }
    }
}
