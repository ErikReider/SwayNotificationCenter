namespace SwayNotificatonCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/notification/notification.ui")]
    private class Notification : Gtk.ListBoxRow {
        [GtkChild]
        unowned Hdy.Carousel carousel;

        [GtkChild]
        unowned Gtk.EventBox event_box;

        [GtkChild]
        unowned Gtk.Button default_button;

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

        private uint timeout_id = 0;

        public NotifyParams param;
        private NotiDaemon notiDaemon;
        private uint timeout_delay;
        private uint timeout_low_delay;

        public delegate void On_hide_cb (Notification noti);

        private unowned On_hide_cb timeout_cb = null;

        public Notification (NotifyParams param,
                             NotiDaemon notiDaemon) {
            build_noti (param, notiDaemon);
            this.body.set_lines (10);
        }

        // Called to show a temp notification
        public Notification.timed (NotifyParams param,
                                   NotiDaemon notiDaemon,
                                   uint timeout,
                                   uint timeout_low,
                                   On_hide_cb callback) {
            this.timeout_delay = timeout;
            this.timeout_low_delay = timeout_low;
            this.timeout_cb = callback;
            build_noti (param, notiDaemon);
            add_noti_timeout ();
        }

        private void build_noti (NotifyParams param, NotiDaemon notiDaemon) {
            this.notiDaemon = notiDaemon;
            this.param = param;

            this.summary.set_text (param.summary ?? param.app_name);

            default_button.clicked.connect (click_default_action);

            close_button.clicked.connect (close_notification);

            this.event_box.enter_notify_event.connect (() => {
                close_revealer.set_reveal_child (true);
                remove_noti_timeout ();
                return false;
            });

            this.event_box.leave_notify_event.connect ((event) => {
                if (event.detail == Gdk.NotifyType.INFERIOR) return true;
                close_revealer.set_reveal_child (false);
                add_noti_timeout ();
                return false;
            });

            this.carousel.scroll_to (event_box);
            this.carousel.page_changed.connect ((_, i) => {
                if (i == 0) close_notification ();
            });

            set_body ();
            set_icon ();
            set_actions ();

            this.show ();
        }

        private void set_body () {
            string text = param.body ?? "";
            string[] img_paths = {};
            if (text.length > 0) {
                try {
                    GLib.Regex img_exp = new Regex (
                        """<img[^>]* src=\"([^\"]*)\"[^>]*>""",
                        RegexCompileFlags.JAVASCRIPT_COMPAT);

                    // Get src paths from images
                    MatchInfo info;
                    if (img_exp.match (text, 0, out info)) {
                        img_paths += Functions.get_match_from_info (info);
                        while (info.next ()) {
                            img_paths += Functions.get_match_from_info (info);
                        }
                    }

                    // Remove all images
                    text = img_exp.replace (text, text.length, 0, "");
                } catch (Error e) {
                    stderr.printf (e.message);
                }
            }

            text = fix_markup (text);
            this.body.set_markup (text);

            try {
                if (img_paths.length > 0) {
                    var img = img_paths[0];
                    var file = File.new_for_path (img);
                    if (img.length > 0 && file.query_exists ()) {
                        const int max_width = 200;
                        const int max_height = 100;
                        var buf = new Gdk.Pixbuf.from_file_at_scale (
                            file.get_path (),
                            max_width,
                            max_height,
                            true);
                        this.body_image.set_from_pixbuf (buf);
                        this.body_image.show ();
                    }
                }
            } catch (Error e) {
                stderr.printf (e.message);
            }
        }

        /** Copied from Elementary OS. Fixes some markup character issues
         * https://github.com/elementary/notifications/blob/ff0668edd9313d8780a68880f054257c3a109971/src/Notification.vala#L137-L142
         */
        private string fix_markup (string markup) {
            string text = markup;
            try {
                Regex entity_regex = new Regex ("&(?!amp;|quot;|apos;|lt;|gt;)");
                text = entity_regex.replace (markup, markup.length, 0, "&amp;");
                Regex tag_regex = new Regex ("<(?!\\/?[biu]>)");
                text = tag_regex.replace (text, text.length, 0, "&lt;");
            } catch (Error e) {
                stderr.printf ("Invalid regex: %s", e.message);
            }
            return text;
        }

        public void click_default_action () {
            action_clicked (param.default_action, true);
        }

        public void click_alt_action (uint index) {
            if (param.actions.length == 0 || index >= param.actions.length) return;
            action_clicked (param.actions[index]);
        }

        private void action_clicked (Action action, bool is_default = false) {
            if (action._identifier != null && action._identifier != "") {
                notiDaemon.ActionInvoked (param.applied_id, action._identifier);
            }
            if (!param.resident) close_notification ();
        }

        private void set_actions () {
            if (param.actions.length > 0) {
                var scroll = new Gtk.ScrolledWindow (null, null);
                var viewport = new Gtk.Viewport (null, null);
                alt_actions_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
                alt_actions_box.set_homogeneous (true);
                alt_actions_box.set_layout (Gtk.ButtonBoxStyle.EXPAND);
                foreach (var action in param.actions) {
                    var actionButton = new Gtk.Button.with_label (action._name);
                    actionButton.clicked.connect (() => action_clicked (action));
                    actionButton.get_style_context ().add_class ("notification-action");
                    actionButton.set_can_focus (false);
                    alt_actions_box.add (actionButton);
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

            double diff = (GLib.get_real_time () * 0.000001) - param.time;
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

        private void close_notification () {
            try {
                notiDaemon.click_close_notification (param.applied_id);
                remove_noti_timeout ();
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
        }

        private void set_icon () {
            img.set_pixel_size (48);

            var img_path_exists = File.new_for_path (param.image_path ?? "").query_exists ();
            var app_icon_exists = File.new_for_path (param.app_icon ?? "").query_exists ();

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
                GLib.Icon ? icon = null;
                foreach (var app in AppInfo.get_all ()) {
                    var entry = app.get_id ();
                    var ref_entry = param.desktop_entry;
                    var entry_same = true;
                    if (entry != null && ref_entry != null) {
                        entry_same = (entry == ref_entry);
                    }

                    if (entry_same && app.get_name ().down () == param.app_name.down ()) {
                        icon = app.get_icon ();
                        break;
                    }
                }
                if (icon != null) {
                    img.set_from_gicon (icon, Gtk.IconSize.DIALOG);
                } else {
                    // Default icon
                    img.set_from_icon_name ("image-missing", Gtk.IconSize.DIALOG);
                }
            }
        }

        private void add_noti_timeout () {
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
                    return;
            }
            uint ms = param.expire_timeout > 0 ? param.expire_timeout : timeout;
            if (param.expire_timeout != 0) {
                timeout_id = Timeout.add (ms, () => {
                    if (timeout_cb != null) timeout_cb (this);
                    return GLib.Source.REMOVE;
                });
            }
        }

        private void remove_noti_timeout () {
            if (timeout_id > 0) {
                Source.remove (timeout_id);
                timeout_id = 0;
            }
        }
    }
}
