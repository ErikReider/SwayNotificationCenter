namespace SwayNotificationCenter.Widgets {
    public class Slider : BaseWidget {
        public override string widget_name {
            get {
                return "slider";
            }
        }

        Gtk.Label label_widget = new Gtk.Label (null);
        Gtk.Scale slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);

        private double min_limit;
        private double max_limit;
        private double ? last_set;
        private bool set_ing = false;

        private string cmd_setter;
        private string cmd_getter;

        public Slider (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            int ? round_digits = 0;

            Json.Object ? config = get_config (this);
            if (config != null) {
                string ? label = get_prop<string> (config, "label");
                label_widget.set_label (label ?? "Slider");

                cmd_setter = get_prop<string> (config, "cmd_setter") ?? "";
                cmd_getter = get_prop<string> (config, "cmd_getter") ?? "";

                int ? min = get_prop<int> (config, "min");
                int ? max = get_prop<int> (config, "max");
                int ? maxl = get_prop<int> (config, "max_limit");
                int ? minl = get_prop<int> (config, "min_limit");
                round_digits = get_prop<int> (config, "value_scale");

                if (min == null)min = 0;
                if (max == null)max = 100;
                if (round_digits == null)round_digits = 0;

                max_limit = maxl != null ? double.min (max, maxl) : max;

                min_limit = minl != null ? double.max (min, minl) : min;

                double scale = Math.pow (10, round_digits);

                min_limit /= scale;
                max_limit /= scale;

                slider.set_range (min / scale, max / scale);
            }

            slider.set_draw_value (false);
            slider.set_round_digits (round_digits);
            slider.value_changed.connect (() => {
                double value = slider.get_value ();
                if (value > max_limit)
                    value = max_limit;
                if (value < min_limit)
                    value = min_limit;

                slider.set_value (value);
                slider.tooltip_text = value.to_string ();

                queue_set.begin (value);
            });

            add (label_widget);
            pack_start (slider, true, true, 0);

            show_all ();
        }

        public async void queue_set (double value) {
            if (cmd_setter != "" && last_set != value) {
                last_set = value;
                if (!set_ing) {
                    set_ing = true;
                    yield Functions.execute_command (cmd_setter + " " + value.to_string (), {}, null);

                    set_ing = false;

                    // make sure the last_set is applied
                    if (value != last_set)
                        queue_set.begin (last_set);
                }
            }
        }

        public async void on_update () {
            if (cmd_getter == "")
                return;

            string value_str = "";
            yield Functions.execute_command (cmd_getter, {}, out value_str);

            double value = double.parse (value_str);
            if (value <= max_limit && value >= min_limit) {
                last_set = value;
                slider.set_value (value);
            }
        }

        public override void on_cc_visibility_change (bool value) {
            if (value)
                on_update.begin ();
        }
    }
}
