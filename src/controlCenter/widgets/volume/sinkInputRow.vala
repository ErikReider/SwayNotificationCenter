namespace SwayNotificationCenter.Widgets {
    public class SinkInputRow : Gtk.ListBoxRow {

        Gtk.Box container;
        Gtk.Image icon = new Gtk.Image ();
        Gtk.Label label = new Gtk.Label (null);
        Gtk.Scale scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);

        public unowned PulseSinkInput sink_input;

        private unowned PulseDaemon client;

        private bool show_per_app_icon;
        private bool show_per_app_label;

        public SinkInputRow (PulseSinkInput sink_input, PulseDaemon client,
                             int icon_size, bool show_per_app_icon, bool show_per_app_label) {
            this.client = client;
            this.show_per_app_icon = show_per_app_icon;
            this.show_per_app_label = show_per_app_label;

            set_activatable (false);

            update (sink_input);

            scale.draw_value = false;
            scale.set_hexpand (true);

            icon.set_pixel_size (icon_size);

            container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            if (show_per_app_icon) {
                container.append (icon);
            }
            if (show_per_app_label) {
                container.append (label);
            }

            container.append (scale);

            set_child (container);

            scale.value_changed.connect (() => {
                client.set_sink_input_volume (sink_input, (float) scale.get_value ());
                scale.tooltip_text = ((int) scale.get_value ()).to_string ();
            });
        }

        public void update (PulseSinkInput sink_input) {
            this.sink_input = sink_input;

            if (show_per_app_icon) {
                string icon_name;
                if (sink_input.application_icon_name != null) {
                    icon_name = sink_input.application_icon_name;
                } else {
                    icon_name = sink_input.application_binary;
                }
                var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
                if (theme.has_icon (icon_name)) {
                    icon.set_from_icon_name (icon_name);
                } else {
                    icon.set_from_icon_name ("application-x-executable");
                }
            }

            if (show_per_app_label) {
                label.set_text (this.sink_input.name);
            }

            scale.set_value (sink_input.volume);
            scale.tooltip_text = ((int) scale.get_value ()).to_string ();
        }
    }
}
