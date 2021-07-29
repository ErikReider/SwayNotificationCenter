namespace SwayNotificatonCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/notification/notification.ui")]
    private class Notification : Gtk.Box {
        [GtkChild]
        unowned Gtk.Button noti_button;

        [GtkChild]
        unowned Gtk.EventBox close_button;

        [GtkChild]
        unowned Gtk.Label summary;
        [GtkChild]
        unowned Gtk.Label time;
        [GtkChild]
        unowned Gtk.TextView body;
        [GtkChild]
        unowned Gtk.Image img;

        private Gtk.TextBuffer buffer;

        private int open_timeout = 0;
        private const int millis = 10000;

        public NotifyParams param;

        public Notification (NotifyParams param,
                             NotiDaemon notiDaemon,
                             bool show = false) {
            this.param = param;

            this.summary.set_text (param.summary);

            buffer = new Gtk.TextBuffer (new Gtk.TextTagTable ());
            buffer.set_text (param.body);
            this.body.set_buffer (buffer);

            noti_button.clicked.connect (() => {
                print ("CLICK\n");
            });

            close_button.button_press_event.connect ((widget, event_button) => {
                try {
                    notiDaemon.click_close_notification (param.applied_id);
                } catch (Error e) {
                    print ("Error: %s\n", e.message);
                }
                return true;
            });

            set_icon ();

            if (show) this.show ();
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

        private void set_icon () {
            if (param.app_icon == "") {
                // Get the app icon
                GLib.Icon ? icon = null;
                foreach (var app in AppInfo.get_all ()) {
                    if (app.get_name ().down () == param.app_name.down ()) {
                        icon = app.get_icon ();
                        break;
                    }
                }
                if (icon != null) {
                    img.set_from_gicon (icon, Gtk.IconSize.DIALOG);
                }
            } else {
                img.set_from_icon_name (param.app_icon, Gtk.IconSize.DIALOG);
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
