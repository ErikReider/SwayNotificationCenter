namespace SwayNotificationCenter.Widgets {
    public class Label : BaseWidget {
        public override string widget_name {
            get {
                return "label";
            }
        }

        Gtk.Label label_widget;

        // Default config values
        string text = "Label Text";
        int max_lines = 5;

        public Label (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config (this);
            if (config != null) {
                // Get text
                string? text = get_prop<string> (config, "text");
                if (text != null) this.text = text;
                // Get max lines
                int? max_lines = get_prop<int> (config, "max-lines");
                if (max_lines != null) this.max_lines = max_lines;
            }

            label_widget = new Gtk.Label (null);
            label_widget.set_text (text);

            label_widget.set_ellipsize (Pango.EllipsizeMode.END);
            label_widget.set_wrap (true);
            label_widget.set_lines (max_lines);
            // Without this and pack_start fill, the label would expand to
            // the monitors full width... GTK bug!...
            label_widget.set_max_width_chars (0);
            label_widget.set_wrap_mode (Pango.WrapMode.WORD_CHAR);
            label_widget.set_justify (Gtk.Justification.LEFT);
            label_widget.set_xalign (0.0f);
            label_widget.set_yalign (0.0f);

            append (label_widget);
        }
    }
}
