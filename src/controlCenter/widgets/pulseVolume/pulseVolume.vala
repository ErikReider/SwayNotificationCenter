using GLib;

namespace SwayNotificationCenter.Widgets {
    public class PulseVolume : BaseWidget {
        public override string widget_name {
            get {
                return "pulse-volume";
            }
        }

        Gtk.Label label_widget;
        Gtk.Scale slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);

        string label = "Volume";
        bool tooltip = true;

        private PulseDevice ? default_sink = null;
        private PulseDaemon client = new PulseDaemon ();

        construct {
            this.client.change_default_device.connect (default_device_changed);

            slider.value_changed.connect (() => {
                this.client.set_device_volume (
                    default_sink,
                    (float) slider.get_value ());
                if (tooltip) this.tooltip_text = ((int) slider.get_value ()).to_string ();
            });
        }


        public PulseVolume (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config (this);
            if (config != null) {
                string ? l = get_prop<string> (config, "label");
                if (l != null) this.label = l;
                bool ? show = get_prop<bool> (config, "draw-value");
                print ("DRAW: %b\n", show);
                if (show != null && show) {
                    slider.draw_value = true;
                    tooltip = false;
                } else if (show != null) slider.draw_value = false;
            }

            label_widget = new Gtk.Label (label);

            if (tooltip) this.tooltip_text = slider.adjustment.value.to_string ();

            add (label_widget);
            pack_start (slider, true, true, 0);

            show_all ();

            this.client.start ();
        }

        private void default_device_changed (PulseDevice device) {
            if (device != null && device.direction == PulseAudio.Direction.OUTPUT) {
                this.default_sink = device;
                slider.set_value (device.volume);
            }
        }
    }
}