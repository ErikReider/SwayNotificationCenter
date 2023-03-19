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

        // Per app volume controll
        Gtk.ListBox levels_listbox;
        Gtk.Button reveal_button;
        Gtk.Revealer revealer;

        string[] show_label = { "⇧", "⇩" };

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
            }

            this.orientation = Gtk.Orientation.VERTICAL;

            slider.draw_value = false;

            main_volume_slider_container.add (label_widget);
            main_volume_slider_container.pack_start (slider, true, true, 0);
            add (main_volume_slider_container);

            if (show_per_app) {
                reveal_button = new Gtk.Button.with_label (show_label[0]);
                revealer = new Gtk.Revealer ();
                levels_listbox = new Gtk.ListBox ();
                levels_listbox.get_style_context ().add_class ("per-app-volume");
                revealer.add (levels_listbox);

                foreach (var item in this.client.active_sinks.values) {
                    levels_listbox.add (new SinkInputRow (item, client));
                }

                this.client.change_active_sink.connect (active_sink_change);
                this.client.new_active_sink.connect (active_sink_added);
                this.client.remove_active_sink.connect (active_sink_removed);

                reveal_button.clicked.connect (() => {
                    bool show = revealer.reveal_child;
                    revealer.set_reveal_child (!show);
                    if (show) {
                        reveal_button.label = show_label[0];
                    } else {
                        reveal_button.label = show_label[1];
                    }
                });

                main_volume_slider_container.pack_end (reveal_button, false, false, 0);
                add (revealer);
            }

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

        private void active_sink_change (PulseSinkInput sink) {
            foreach (var row in levels_listbox.get_children ()) {
                if (row == null) continue;
                var s = (SinkInputRow) row;
                if (s.sink_input.cmp (sink)) {
                    s.update (sink);
                    break;
                }
            }
        }

        private void active_sink_added (PulseSinkInput sink) {
            levels_listbox.add (new SinkInputRow (sink, client));
            show_all ();
        }

        private void active_sink_removed (PulseSinkInput sink) {
            foreach (var row in levels_listbox.get_children ()) {
                if (row == null) continue;
                var s = (SinkInputRow) row;
                if (s.sink_input.cmp (sink)) {
                    levels_listbox.remove (row);
                    break;
                }
            }
            if (levels_listbox.get_children ().length () == 0) {
                print ("EMPTY\n");
            }
        }
    }
}