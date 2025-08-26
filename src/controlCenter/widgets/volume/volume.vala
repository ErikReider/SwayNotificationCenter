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
        Gtk.ListBox levels_listbox;
        IterListBoxController list_box_controller;
        Gtk.ToggleButton reveal_button;
        Gtk.Revealer revealer;
        Gtk.Label no_sink_inputs_label;
        string empty_label = "No active sink input";

        string ? expand_label = null;
        string ? collapse_label = null;

        [Version (deprecated = true, replacement = "CSS root variable")]
        int icon_size = -1;

        Gtk.RevealerTransitionType revealer_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        int revealer_duration = 250;

        private PulseDevice ? default_sink = null;
        private PulseDaemon client = new PulseDaemon ();

        private bool show_per_app;
        private bool show_per_app_icon = true;
        private bool show_per_app_label = false;

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

                bool show_per_app_found;
                bool ? show_per_app = get_prop<bool> (config, "show-per-app", out show_per_app_found);
                if (show_per_app_found) this.show_per_app = show_per_app;

                bool show_per_app_icon_found;
                bool ? show_per_app_icon = get_prop<bool> (config, "show-per-app-icon", out show_per_app_icon_found);
                if (show_per_app_icon_found) this.show_per_app_icon = show_per_app_icon;

                bool show_per_app_label_found;
                bool ? show_per_app_label = get_prop<bool> (config, "show-per-app-label", out show_per_app_label_found);
                if (show_per_app_label_found) this.show_per_app_label = show_per_app_label;

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
            slider.set_hexpand (true);

            main_volume_slider_container.append (label_widget);
            main_volume_slider_container.append (slider);
            append (main_volume_slider_container);

            if (show_per_app) {
                revealer = new Gtk.Revealer ();
                revealer.transition_type = revealer_type;
                revealer.transition_duration = revealer_duration;
                levels_listbox = new Gtk.ListBox ();
                levels_listbox.add_css_class ("per-app-volume");
                levels_listbox.set_activate_on_single_click (true);
                levels_listbox.set_selection_mode (Gtk.SelectionMode.NONE);
                revealer.set_child (levels_listbox);

                list_box_controller = new IterListBoxController (levels_listbox);

                if (this.client.active_sinks.size == 0) {
                    no_sink_inputs_label = new Gtk.Label (empty_label);
                    list_box_controller.append (no_sink_inputs_label);
                }

                foreach (var item in this.client.active_sinks.values) {
                    SinkInputRow row = new SinkInputRow (item, client,
                                                         icon_size, show_per_app_icon,
                                                         show_per_app_label);
                    list_box_controller.append (row);
                }

                this.client.change_active_sink.connect (active_sink_change);
                this.client.new_active_sink.connect (active_sink_added);
                this.client.remove_active_sink.connect (active_sink_removed);

                reveal_button = new Gtk.ToggleButton ();
                set_button_icon ();
                reveal_button.toggled.connect (() => {
                    set_button_icon ();
                    revealer.set_reveal_child (reveal_button.active);
                });
                main_volume_slider_container.append (reveal_button);
                append (revealer);
            }
        }

        private void set_button_icon () {
            if (!reveal_button.active) {
                if (expand_label == null) {
                    reveal_button.set_icon_name ("swaync-up-small-symbolic");
                } else {
                    reveal_button.set_label (expand_label);
                }
            } else {
                if (collapse_label == null) {
                    reveal_button.set_icon_name ("swaync-down-small-symbolic");
                } else {
                    reveal_button.set_label (collapse_label);
                }
            }
        }

        public override void on_cc_visibility_change (bool val) {
            if (val) {
                this.client.start ();
            } else {
                this.client.close ();
                if (show_per_app) {
                    reveal_button.set_active (false);
                }
            }
        }

        private void default_device_changed (PulseDevice device) {
            if (device != null && device.direction == PulseAudio.Direction.OUTPUT) {
                this.default_sink = device;
                slider.set_value (device.volume);
            }
        }

        private void active_sink_change (PulseSinkInput sink) {
            foreach (unowned Gtk.Widget row in list_box_controller.get_children ()) {
                if (!(row is SinkInputRow)) {
                    continue;
                }
                var s = (SinkInputRow) row;
                if (s.sink_input.cmp (sink)) {
                    s.update (sink);
                    break;
                }
            }
        }

        private void active_sink_added (PulseSinkInput sink) {
            // one element added -> remove the empty label
            if (this.client.active_sinks.size == 1) {
                var label = levels_listbox.get_first_child ();
                list_box_controller.remove ((Gtk.Widget) label);
            }
            SinkInputRow row = new SinkInputRow (sink, client,
                                                 icon_size, show_per_app_icon,
                                                 show_per_app_label);
            list_box_controller.append (row);
        }

        private void active_sink_removed (PulseSinkInput sink) {
            foreach (unowned Gtk.Widget row in list_box_controller.get_children ()) {
                if (!(row is SinkInputRow)) {
                    continue;
                }
                var s = (SinkInputRow) row;
                if (s.sink_input.cmp (sink)) {
                    list_box_controller.remove (row);
                    break;
                }
            }
            if (levels_listbox.get_first_child () == null) {
                list_box_controller.append (no_sink_inputs_label);
            }
        }
    }
}
