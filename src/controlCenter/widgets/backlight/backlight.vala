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
                string device = (get_prop<string> (config, "device") ?? "intel_backlight");
                string subsystem = (get_prop<string> (config, "subsystem") ?? "backlight");
                int min = int.max (0, get_prop<int> (config, "min"));

                switch (subsystem) {
                    default:
                    case "backlight":
                        if (subsystem != "backlight")
                            info ("Invalid subsystem %s for device %s. " +
                                  "Use 'backlight' or 'leds'. Using default: 'backlight'",
                                  subsystem, device);
                        client = new BacklightUtil ("backlight", device);
                        slider.set_range (min, 100);
                        break;
                    case "leds":
                        client = new BacklightUtil ("leds", device);
                        slider.set_range (min, this.client.get_max_value ());
                        break;
                }
            }

            this.client.brightness_change.connect ((percent) => {
                if (percent < 0) { // invalid device path
                    hide ();
                } else {
                    slider.set_value (percent);
                }
            });

            slider.set_draw_value (false);
            slider.set_round_digits (0);
            slider.value_changed.connect (() => {
                this.client.set_brightness.begin ((float) slider.get_value ());
                slider.tooltip_text = ((int) slider.get_value ()).to_string ();
            });

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
    }
}
