namespace SwayNotificationCenter.Widgets {
    public class Volume : BaseWidget {
        public override string widget_name {
            get {
                return "volume";
            }
        }

        Gtk.Box main_volume_slider_container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        Gtk.Label label_widget = new Gtk.Label (null);
        Gtk.Scale slider = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0, 100, 1);

        // Per app volume control
        List<unowned Gtk.Widget> levels_rows = new List<unowned Gtk.Widget> ();
        Gtk.ListBox levels_listbox = new Gtk.ListBox ();
        Gtk.Button reveal_button;
        Gtk.Revealer revealer;
        string empty_label = "No active sink input";

        string expand_label = "⇧";
        string collapse_label = "⇩";
        int icon_size = 24;

        Gtk.RevealerTransitionType revealer_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        int revealer_duration = 250;

        private PulseDevice ? default_sink = null;
        private PulseDaemon client = new PulseDaemon ();

        private bool show_per_app;

        construct {
            this.client.change_default_device.connect (default_device_changed);

            slider.value_changed.connect (() => {
                if (default_sink != null) {
                    this.client.set_device_volume (
                        default_sink,
                        (float) slider.get_value ());
                    slider.tooltip_text = ((int) slider.get_value ()).to_string ();
                }
            });
        }

        public Volume (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config (this);
            if (config != null) {
                string ? label = get_prop<string> (config, "label");
                label_widget.set_label (label ?? "Volume");

                show_per_app = get_prop<bool> (config, "show-per-app") ? true : false;

                string ? el = get_prop<string> (config, "empty-list-label");
                if (el != null) empty_label = el;

                string ? l1 = get_prop<string> (config, "expand-button-label");
                if (l1 != null) expand_label = l1;
                string ? l2 = get_prop<string> (config, "collapse-button-label");
                if (l2 != null) collapse_label = l2;

                int i = int.max (get_prop<int> (config, "icon-size"), 0);
                if (i != 0) icon_size = i;

                revealer_duration = int.max (0, get_prop<int> (config, "animation-duration"));
                if (revealer_duration == 0) revealer_duration = 250;

                string ? animation_type = get_prop<string> (config, "animation-type");
                if (animation_type != null) {
                    switch (animation_type) {
                        default:
                        case "none":
                            revealer_type = Gtk.RevealerTransitionType.NONE;
                            break;
                        case "slide_up":
                            revealer_type = Gtk.RevealerTransitionType.SLIDE_UP;
                            break;
                        case "slide_down":
                            revealer_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
                            break;
                    }
                }
            }

            this.orientation = Gtk.Orientation.VERTICAL;

            slider.draw_value = false;
            slider.hexpand = true;

            main_volume_slider_container.append (label_widget);
            main_volume_slider_container.append (slider);
            append (main_volume_slider_container);

            if (show_per_app) {
                reveal_button = new Gtk.Button.with_label (expand_label);
                revealer = new Gtk.Revealer ();
                revealer.transition_type = revealer_type;
                revealer.transition_duration = revealer_duration;
                levels_listbox.add_css_class ("per-app-volume");
                levels_listbox.set_placeholder (new Gtk.Label (empty_label));
                revealer.set_child (levels_listbox);

                foreach (var item in this.client.active_sinks.values) {
                    var row = new SinkInputRow (item, client, icon_size);
                    levels_rows.append (row);
                    levels_listbox.append (levels_rows.last ().data);
                }

                this.client.change_active_sink.connect (active_sink_change);
                this.client.new_active_sink.connect (active_sink_added);
                this.client.remove_active_sink.connect (active_sink_removed);

                reveal_button.clicked.connect (() => {
                    bool show = revealer.reveal_child;
                    revealer.set_reveal_child (!show);
                    if (show) {
                        reveal_button.label = expand_label;
                    } else {
                        reveal_button.label = collapse_label;
                    }
                });

                main_volume_slider_container.append (reveal_button);
                append (revealer);
            }
        }

        public override void on_cc_visibility_change (bool val) {
            if (val) {
                this.client.start ();
            } else {
                this.client.close ();
                if (show_per_app) revealer.set_reveal_child (false);
            }
        }

        private void default_device_changed (PulseDevice device) {
            if (device != null && device.direction == PulseAudio.Direction.OUTPUT) {
                this.default_sink = device;
                slider.set_value (device.volume);
            }
        }

        private void active_sink_change (PulseSinkInput sink) {
            foreach (var widget in levels_rows) {
                if (!(widget is SinkInputRow)) continue;
                var row = (SinkInputRow) widget;
                if (row.sink_input.cmp (sink)) {
                    row.update (sink);
                    break;
                }
            }
        }

        private void active_sink_added (PulseSinkInput sink) {
            var row = new SinkInputRow (sink, client, icon_size);
            levels_rows.append (row);
            levels_listbox.append (row);
        }

        private void active_sink_removed (PulseSinkInput sink) {
            foreach (var widget in levels_rows) {
                if (!(widget is SinkInputRow)) continue;
                var row = (SinkInputRow) widget;
                if (row.sink_input.cmp (sink)) {
                    levels_rows.remove (row);
                    levels_listbox.remove (row);
                    break;
                }
            }
        }
    }
}
