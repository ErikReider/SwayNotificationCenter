namespace SwayNotificationCenter.Widgets {
    public class SinkInputRow : Gtk.ListBoxRow {

        Gtk.Box container;
        Gtk.Image icon = new Gtk.Image ();
        Gtk.Scale scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);

        public unowned PulseSinkInput sink_input;

        private unowned PulseDaemon client;

        public SinkInputRow (PulseSinkInput sink_input, PulseDaemon client, int icon_size) {
            this.client = client;

            update (sink_input);

            scale.draw_value = false;

            icon.pixel_size = icon_size;

            container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            container.add (icon);

            container.pack_start (scale);

            add (container);

            scale.value_changed.connect (() => {
                client.set_sink_input_volume (sink_input, (float) scale.get_value ());
                scale.tooltip_text = ((int) scale.get_value ()).to_string ();
            });
        }

        public void update (PulseSinkInput sink_input) {
            this.sink_input = sink_input;

            icon.set_from_icon_name (
                sink_input.application_icon_name ?? "application-x-executable",
                Gtk.IconSize.DIALOG
            );

            scale.set_value (sink_input.volume);
            scale.tooltip_text = ((int) scale.get_value ()).to_string ();

            this.show_all ();
        }
    }
}
