using GLib;

namespace SwayNotificationCenter.Widgets {
    public class Backlight : BaseWidget {
        public override string widget_name {
            get {
                return "backlight";
            }
        }

        BacklightUtil client;

        Gtk.Label label_widget = new Gtk.Label (null);
        Gtk.Scale slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);

        public Backlight (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config (this);
            if (config != null) {
                string ? label = get_prop<string> (config, "label");
                label_widget.set_label (label ?? "Brightness");
                string ? device = get_prop<string> (config, "device");
                string ? subsystem = get_prop<string> (config, "subsystem");
                if (subsystem != "backlight" && subsystem != "leds") {
                    info ("Invalid subsystem for device %s. Use 'backlight' or 'leds'. Using default: 'backlight'", device);
                    subsystem = "backlight";
                }
                client = new BacklightUtil (subsystem ?? "backlight", device ?? "intel_backlight");

                int ? min = get_prop<int> (config, "min");
                if (min == null) min = 0;
                if (subsystem == "backlight") slider.set_range (min, 100);
                else if (subsystem == "leds") slider.set_range (min, this.client.get_max_value ());
            }

            this.client.brightness_change.connect (brightness_changed);

            slider.set_draw_value (false);
            slider.set_round_digits (0);
            slider.value_changed.connect (() => {
                this.client.set_brightness ((float) slider.get_value ());
                slider.tooltip_text = ((int) slider.get_value ()).to_string ();
            });

            add (label_widget);
            pack_start (slider, true, true, 0);

            show_all ();
        }

        public void brightness_changed (int percent) {
            slider.set_value (percent);
        }

        public override void on_cc_visibility_change (bool val) {
            if (val) {
                this.client.start ();
            } else {
                this.client.close ();
            }
        }
    }
}