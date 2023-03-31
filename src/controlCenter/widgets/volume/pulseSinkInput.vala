// From SwaySettings PulseAudio page: https://github.com/ErikReider/SwaySettings/blob/2b05776bce2fd55933a7fbdec995f54849e39e7d/src/Pages/Pulse/PulseSinkInput.vala
using PulseAudio;
using Gee;

namespace SwayNotificationCenter.Widgets {
    public class PulseSinkInput : Object {
        /** The card index: ex. `Sink Input #227` */
        public uint32 index;
        /** The sink index: ex. `55` */
        public uint32 sink_index;
        /** The client index: ex. `266` */
        public uint32 client_index;

        /** The name of the application: `application.name` */
        public string name;
        /** The name of the application binary: `application.process.binary` */
        public string application_binary;
        /** The application icon. Can be null: `application.icon_name` */
        public string ? application_icon_name;
        /** The name of the media: `media.name` */
        public string media_name;

        /** The mute state: `Mute` */
        public bool is_muted;

        public double volume;
        public float balance { get; set; default = 0; }
        public CVolume cvolume;
        public ChannelMap channel_map;
        public LinkedList<Operation> volume_operations;

        public bool active;

        /** Gets the name to be shown to the user:
         * "application_name"
         */
        public string ? get_display_name () {
            return name;
        }

        public bool cmp (PulseSinkInput sink_input) {
            return sink_input.index == index
                   && sink_input.sink_index == sink_index
                   && sink_input.client_index == client_index
                   && sink_input.name == name
                   && sink_input.application_binary == application_binary
                   && sink_input.is_muted == is_muted
                   && sink_input.volume == volume;
        }

        /** Gets the name to be shown to the user:
         * "index:application_name"
         */
        public static uint32 get_hash_map_key (uint32 i) {
            return i;
        }

        construct {
            volume_operations = new LinkedList<Operation> ();
        }
    }

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
                sink_input.application_icon_name ?? "application-c-executable",
                Gtk.IconSize.DIALOG
            );

            scale.set_value (sink_input.volume);
            scale.tooltip_text = ((int) scale.get_value ()).to_string ();

            this.show_all ();
        }
    }
}
