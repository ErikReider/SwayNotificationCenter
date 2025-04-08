namespace SwayNotificationCenter.Widgets {
    public class Inhibitors : BaseWidget {
        public override string widget_name {
            get {
                return "inhibitors";
            }
        }

        Gtk.Label title_widget;
        Gtk.Button clear_all_button;

        // Default config values
        string title = "Inhibitors";
        bool has_clear_all_button = true;
        string button_text = "Clear All";

        public Inhibitors (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            swaync_daemon.inhibited_changed.connect ((length) => {
                if (!swaync_daemon.inhibited) {
                    hide ();
                    return;
                }
                show ();
                title_widget.set_text ("%s %u".printf (title, length));
            });

            Json.Object ? config = get_config (this);
            if (config != null) {
                // Get title
                string ? title = get_prop<string> (config, "text");
                if (title != null) this.title = title;
                // Get has clear-all-button
                bool found_clear_all;
                bool ? has_clear_all_button = get_prop<bool> (
                    config, "clear-all-button", out found_clear_all);
                if (found_clear_all) this.has_clear_all_button = has_clear_all_button;
                // Get button text
                string ? button_text = get_prop<string> (config, "button-text");
                if (button_text != null) this.button_text = button_text;
            }

            title_widget = new Gtk.Label (title);
            title_widget.set_halign (Gtk.Align.START);
            title_widget.set_hexpand (true);
            title_widget.show ();
            append (title_widget);

            if (has_clear_all_button) {
                clear_all_button = new Gtk.Button.with_label (button_text);
                clear_all_button.clicked.connect (() => {
                    try {
                        swaync_daemon.clear_inhibitors ();
                    } catch (Error e) {
                        error ("Error: %s\n", e.message);
                    }
                });
                clear_all_button.set_can_focus (false);
                clear_all_button.valign = Gtk.Align.CENTER;
                clear_all_button.show ();
                append (clear_all_button);
            }

            hide ();
        }
    }
}
