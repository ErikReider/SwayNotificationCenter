namespace SwayNotificationCenter.Widgets {
    public class Dnd : Gtk.Box, BaseWidget {
        public string key {
            get {
                return "dnd";
            }
        }

        private unowned SwayncDaemon swaync_daemon;
        private unowned NotiDaemon noti_daemon;

        Gtk.Label title_widget;
        Gtk.Switch dnd_button;

        // Default config values
        string title = "Do Not Disturb";

        public Dnd (SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            this.swaync_daemon = swaync_daemon;
            this.noti_daemon = noti_daemon;

            Json.Object ? config = get_config (this);
            if (config != null) {
                // Get title
                get_prop<string> (config, "text", ref title);
            }

            // Title
            title_widget = new Gtk.Label (title);
            title_widget.get_style_context ().add_class ("widget-dnd-title");
            add (title_widget);

            // Dnd button
            dnd_button = new Gtk.Switch () {
                state = noti_daemon.dnd,
            };
            dnd_button.state_set.connect (state_set);
            noti_daemon.on_dnd_toggle.connect ((dnd) => {
                dnd_button.state_set.disconnect (state_set);
                dnd_button.set_active (dnd);
                dnd_button.state_set.connect (state_set);
            });

            dnd_button.set_can_focus (false);
            dnd_button.valign = Gtk.Align.CENTER;
            dnd_button.get_style_context ().add_class ("widget-dnd-clear-all");
            dnd_button.get_style_context ().add_class ("control-center-dnd");
            pack_end (dnd_button, false);

            show_all ();
        }

        private bool state_set (Gtk.Widget widget, bool state) {
            noti_daemon.dnd = state;
            return false;
        }
    }
}
