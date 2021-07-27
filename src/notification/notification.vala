namespace SwayNotificatonCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/notification/notification.ui")]
    private class Notification : Gtk.Box {

        [GtkChild]
        unowned Gtk.EventBox eventBox;

        [GtkChild]
        unowned Gtk.EventBox close_button;

        [GtkChild]
        unowned Gtk.Label summary;
        [GtkChild]
        unowned Gtk.Label body;
        [GtkChild]
        unowned Gtk.Image img;

        private int open_timeout = 0;
        private const int millis = 5000;

        public NotifyParams param;

        public Notification (NotifyParams param,
                             NotiDaemon notiDaemon,
                             bool show = false) {
            this.param = param;

            this.summary.set_text (param.summary);
            this.body.set_text (param.body);

            eventBox.button_press_event.connect ((widget, event_button) => {
                print (widget.get_name ());
                return false;
            });

            close_button.button_press_event.connect ((widget, event_button) => {
                try {
                    notiDaemon.click_close_notification (param.applied_id);
                } catch (Error e) {
                    print ("Error: %s\n", e.message);
                }
                return false;
            });

            set_icon ();

            if (show) this.show_all ();
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
                Timeout.add ((int) (ms), () => {
                    open_timeout--;
                    if (open_timeout == 0) callback (this);
                    return false;
                });
            }
        }
    }
}
