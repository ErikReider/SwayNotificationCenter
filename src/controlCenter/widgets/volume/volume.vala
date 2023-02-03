using GLib;

namespace SwayNotificationCenter.Widgets {
    public class Volume : BaseWidget {
        public override string widget_name {
            get {
                return "volume";
            }
        }

        Gtk.Label label_widget;
        Gtk.Scale slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);

        string label = "Volume";

        private PulseDevice ? default_sink = null;
        private PulseDaemon client = new PulseDaemon ();

        construct {
            this.client.change_default_device.connect (default_device_changed);

            slider.value_changed.connect (() => {
                this.client.set_device_volume (
                    default_sink,
                    (float) slider.get_value ());
                slider.tooltip_text = ((int) slider.get_value ()).to_string ();
            });
        }


        public Volume (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config (this);
            if (config != null) {
                string ? l = get_prop<string> (config, "label");
                if (l != null) this.label = l;
            }

            slider.draw_value = false;

            label_widget = new Gtk.Label (label);

            add (label_widget);
            pack_start (slider, true, true, 0);

            show_all ();
        }

        public override void on_cc_visibility_change (bool val) {
            if (val) {
                this.client.start ();
            } else {
                this.client.close ();
            }
        }

        private void default_device_changed (PulseDevice device) {
            if (device != null && device.direction == PulseAudio.Direction.OUTPUT) {
                this.default_sink = device;
                slider.set_value (device.volume);
            }
        }
    }
}