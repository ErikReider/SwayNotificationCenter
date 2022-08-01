namespace SwayNotificationCenter.Widgets {
    public class Title :  BaseWidget {
        public override string widget_name {
            get {
                return "title";
            }
        }

        Gtk.Label title_widget;
        Gtk.Button clear_all_button;

        // Default config values
        string title = "Notifications";
        bool has_clear_all_button = true;
        string button_text = "Clear All";

        public Title (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base(suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config (this);
            if (config != null) {
                // Get title
                get_prop<string> (config, "text", ref title);
                // Get has clear-all-button
                get_prop<bool> (config, "clear-all-button", ref has_clear_all_button);
                get_prop<string> (config, "button-text", ref button_text);
            }

            title_widget = new Gtk.Label (title);
            title_widget.get_style_context ().add_class ("widget-title");
            add (title_widget);

            if (has_clear_all_button) {
                clear_all_button = new Gtk.Button.with_label (button_text);
                clear_all_button.clicked.connect (() => {
                    try {
                        swaync_daemon.close_all_notifications ();
                    } catch (Error e) {
                        error ("Error: %s\n", e.message);
                    }
                });
                clear_all_button.set_can_focus (false);
                clear_all_button.valign = Gtk.Align.CENTER;
                clear_all_button.get_style_context ().add_class ("control-center-clear-all");
                clear_all_button.get_style_context ().add_class ("widget-title-clear-all");
                pack_end (clear_all_button, false);
            }

            show_all ();
        }
    }
}
