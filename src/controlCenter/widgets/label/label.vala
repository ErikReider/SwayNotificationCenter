namespace SwayNotificationCenter.Widgets {
    public class Label : Gtk.Box, BaseWidget {
        public string key {
            get {
                return "label";
            }
        }

        private unowned SwayncDaemon swaync_daemon;
        private unowned NotiDaemon noti_daemon;

        Gtk.Label label_widget;

        // Default config values
        string text = "Label Text";
        int max_lines = 5;

        public Label (SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            this.swaync_daemon = swaync_daemon;
            this.noti_daemon = noti_daemon;

            Json.Object ? config = get_config (this);
            if (config != null) {
                // Get text
                get_prop<string> (config, "text", ref text);
                // Get max lines
                get_prop<int> (config, "max-lines", ref max_lines);
            }

            label_widget = new Gtk.Label (null);
            label_widget.set_text (text);

            label_widget.get_style_context ().add_class ("widget-label");
            label_widget.set_ellipsize (Pango.EllipsizeMode.END);
            label_widget.set_line_wrap (true);
            label_widget.set_lines (max_lines);
            // Without this and pack_start fill, the label would expand to
            // the monitors full width... GTK bug!...
            label_widget.set_max_width_chars (0);
            label_widget.set_line_wrap_mode (Pango.WrapMode.WORD_CHAR);
            label_widget.set_justify (Gtk.Justification.LEFT);
            label_widget.set_alignment (0, 0);

            pack_start (label_widget, true, true, 0);

            show_all ();
        }
    }
}
