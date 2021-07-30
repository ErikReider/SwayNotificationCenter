namespace SwayNotificatonCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/notification/notification.ui")]
    private class Notification : Gtk.Box {
        [GtkChild]
        unowned Gtk.Button noti_button;

        [GtkChild]
        unowned Gtk.Button close_button;

        private Gtk.ButtonBox button_box;

        [GtkChild]
        unowned Gtk.Box base_box;

        [GtkChild]
        unowned Gtk.Label summary;
        [GtkChild]
        unowned Gtk.Label time;
        [GtkChild]
        unowned Gtk.Label body;
        [GtkChild]
        unowned Gtk.Image img;

        private int open_timeout = 0;
        private const int millis = 10000;

        public NotifyParams param;
        private NotiDaemon notiDaemon;

        public Notification (NotifyParams param,
                             NotiDaemon notiDaemon,
                             bool show = false) {
            this.notiDaemon = notiDaemon;
            this.param = param;

            this.summary.set_text (param.summary ?? param.app_name);
            this.body.set_text (param.body ?? "");

            noti_button.clicked.connect (() => action_clicked (param.default_action));

            close_button.clicked.connect (close_notification);

            set_icon ();
            set_actions ();

            if (show) {
                this.body.set_lines (10);
                this.show ();
            }
        }

        private void action_clicked (Action action, bool is_default = false) {
            if (action._identifier != null && action._identifier != "") {
                notiDaemon.ActionInvoked (param.applied_id, action._identifier);
            }
            if (!param.resident) {
                close_notification ();
            }
        }

        private void set_actions () {
            if (param.actions.length > 0) {
                button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
                button_box.set_layout (Gtk.ButtonBoxStyle.EXPAND);
                foreach (var action in param.actions) {
                    var actionButton = new Gtk.Button.with_label (action._name);
                    actionButton.clicked.connect (() => action_clicked (action));
                    actionButton.get_style_context ().add_class ("notification-action");
                    button_box.add (actionButton);
                }
                button_box.show_all ();
                base_box.add (button_box);
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
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
        }

        private void set_icon () {
            img.set_pixel_size (48);
            if (param.image_data.is_initialized) {
                Functions.set_image_data (param.image_data, img);
            } else if (param.image_path != null && param.image_path != "") {
                Functions.set_image_path (param.image_path, img);
            } else if (param.app_icon != null && param.app_icon != "") {
                Functions.set_image_path (param.app_icon, img);
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

        public delegate void On_hide_cb (Notification noti);

        // Called to show a temp notification
        public void show_notification (On_hide_cb callback) {
            this.show ();
            int ms = param.expire_timeout > 0 ? param.expire_timeout : millis;
            if (param.expire_timeout != 0) {
                open_timeout = 1;
                Timeout.add (ms, () => {
                    open_timeout--;
                    if (open_timeout == 0) callback (this);
                    return false;
                });
            }
        }
    }
}
