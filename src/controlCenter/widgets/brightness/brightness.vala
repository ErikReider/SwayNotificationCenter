using GLib;

namespace SwayNotificationCenter.Widgets {
    public class Brightness : BaseWidget {
        public override string widget_name {
            get {
                return "brightness";
            }
        }

        BrightnessUtil client;

        string device = "intel_backlight";
        string label = "Brightness";

        Gtk.Label label_widget;
        Gtk.Scale slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);

        public Brightness (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config (this);
            if (config != null) {
                string ? l = get_prop<string> (config, "label");
                if (l != null) this.label = l;
                string ? d = get_prop<string> (config, "device");
                if (d != null) this.device = d;
            }

            client = new BrightnessUtil ("intel_backlight");
            this.client.brightness_change.connect (brightness_changed);

            label_widget = new Gtk.Label (label);

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