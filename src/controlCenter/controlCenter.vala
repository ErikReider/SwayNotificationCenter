namespace SwayNotificationCenter {
    [GtkTemplate (ui = "/org/erikreider/swaync/ui/control_center.ui")]
    public class ControlCenter : Gtk.ApplicationWindow {
        [GtkChild]
        unowned Gtk.ScrolledWindow window;
        [GtkChild]
        unowned IterBox box;

        private unowned Widgets.Notifications notifications;

        private Gtk.GestureClick blank_window_gesture;
        private bool blank_window_down = false;
        private bool blank_window_in = false;

        private Gtk.EventControllerKey key_controller;

        private SwayncDaemon swaync_daemon;
        private NotiDaemon noti_daemon;

        /** Unsorted list of copies of all notifications */
        private List<Widgets.BaseWidget> widgets;
        private const string[] DEFAULT_WIDGETS = { "title", "dnd", "notifications" };

        private string ? monitor_name = null;

        public ControlCenter (SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            Object (css_name: "blankwindow");
            this.swaync_daemon = swaync_daemon;
            this.noti_daemon = noti_daemon;


            widgets = new List<Widgets.BaseWidget> ();
            widgets.append (new Widgets.Notifications (swaync_daemon, noti_daemon));
            this.notifications = (Widgets.Notifications) widgets.nth_data (0);

            if (swaync_daemon.use_layer_shell) {
                if (!GtkLayerShell.is_supported ()) {
                    stderr.printf ("GTKLAYERSHELL IS NOT SUPPORTED!\n");
                    stderr.printf ("Swaync only works on Wayland!\n");
                    stderr.printf ("If running wayland session, try running:\n");
                    stderr.printf ("\tGDK_BACKEND=wayland swaync\n");
                    Process.exit (1);
                }
                GtkLayerShell.init_for_window (this);
                GtkLayerShell.set_namespace (this, "swaync-control-center");
                set_anchor ();
            }

            this.map.connect (() => {
                set_anchor ();

                unowned Gdk.Surface surface = get_surface ();
                if (!(surface is Gdk.Surface)) {
                    return;
                }

                ulong id = 0;
                id = surface.enter_monitor.connect ((monitor) => {
                    surface.disconnect (id);
                    swaync_daemon.show_blank_windows (monitor);
                });
            });
            this.unmap.connect (swaync_daemon.hide_blank_windows);

            /*
             * Handling of bank window presses (pressing outside of ControlCenter)
             */
            blank_window_gesture = new Gtk.GestureClick ();
            ((Gtk.Widget) this).add_controller (blank_window_gesture);
            blank_window_gesture.touch_only = false;
            blank_window_gesture.exclusive = true;
            blank_window_gesture.button = Gdk.BUTTON_PRIMARY;
            blank_window_gesture.propagation_phase = Gtk.PropagationPhase.BUBBLE;
            blank_window_gesture.pressed.connect ((n_press, x, y) => {
                // Calculate if the clicked coords intersect the ControlCenter
                Graphene.Point click_point = Graphene.Point ()
                    .init ((float) x, (float) y);
                Graphene.Rect ? bounds = null;
                window.compute_bounds (this, out bounds);
                blank_window_in = !(bounds != null && bounds.contains_point (click_point));
                blank_window_down = true;
            });
            blank_window_gesture.released.connect ((n_press, x, y) => {
                // Emit released
                if (!blank_window_down) return;
                blank_window_down = false;
                if (blank_window_in) {
                    try {
                        swaync_daemon.set_visibility (false);
                    } catch (Error e) {
                        stderr.printf ("ControlCenter BlankWindow Click Error: %s\n",
                                       e.message);
                    }
                }

                if (blank_window_gesture.get_current_sequence () == null) {
                    blank_window_in = false;
                }
            });
            blank_window_gesture.update.connect ((gesture, sequence) => {
                Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
                if (sequence != gesture_single.get_current_sequence ()) return;
                // Calculate if the clicked coords intersect the ControlCenter
                double x, y;
                gesture.get_point (sequence, out x, out y);
                Graphene.Point click_point = Graphene.Point ()
                    .init ((float) x, (float) y);
                Graphene.Rect ? bounds = null;
                window.compute_bounds (this, out bounds);
                if (bounds != null && bounds.contains_point (click_point)) {
                    blank_window_in = false;
                }
            });
            blank_window_gesture.cancel.connect (() => {
                blank_window_down = false;
            });

            // Only use release for closing notifications due to Escape key
            // sometimes being passed through to unfucused application
            // Ex: Firefox in a fullscreen YouTube video
            key_controller = new Gtk.EventControllerKey ();
            key_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            ((Gtk.Widget) this).add_controller (key_controller);
            key_controller.key_released.connect (key_released_event_cb);
            key_controller.key_pressed.connect (key_press_event_cb);

            add_widgets ();

            // Change output on config reload
            app.config_reload.connect ((old, config) => {
                string monitor_name = config.control_center_preferred_output;
                if (old == null
                    || old.control_center_preferred_output != monitor_name
                    || this.monitor_name != monitor_name) {
                    this.monitor_name = null;
                    set_anchor ();
                }
            });
        }

        private void key_released_event_cb (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (this.get_focus () is Gtk.Entry) {
                switch (Gdk.keyval_name (keyval)) {
                    case "Escape":
                        this.set_focus (null);
                        return;
                }
                return;
            }
            switch (Gdk.keyval_name (keyval)) {
                case "Escape":
                case "Caps_Lock":
                    this.set_visibility (false);
                    return;
            }
        }

        private bool key_press_event_cb (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (get_focus () is Gtk.Text) {
                return false;
            }
            switch (Gdk.keyval_name (keyval)) {
                case "D":
                    try {
                        swaync_daemon.toggle_dnd ();
                    } catch (Error e) {
                        critical ("Error: %s\n", e.message);
                    }
                    break;
                default:
                    return notifications.key_press_event_cb (keyval, keycode, state);
            }
            // Override the builtin list navigation
            return true;
        }

        /** Adds all custom widgets. Removes previous widgets */
        public void add_widgets () {
            // Remove all widgets
            widgets.foreach ((widget) => {
                if (widget.get_parent () == box) {
                    box.remove (widget);
                }
                // Except for notifications. Otherwise we'd loose notifications
                if (widget is Widgets.Notifications) {
                    return;
                }
                widgets.remove (widget);
            });

            string[] w = ConfigModel.instance.widgets.data;
            if (w.length == 0) w = DEFAULT_WIDGETS;

            // Add the notifications widget if not found in the list
            if (!("notifications" in w)) {
                warning ("Notification widget not included in \"widgets\" config. Using default bottom position");
                w += "notifications";
            }
            bool has_notifications = false;
            foreach (string key in w) {
                // Add the widget if it is valid
                bool is_notifications;
                Widgets.BaseWidget ? widget = Widgets.get_widget_from_key (
                    key, swaync_daemon, noti_daemon, out is_notifications);

                if (is_notifications) {
                    if (has_notifications) {
                        warning ("Cannot have multiple \"notifications\" widgets! Skipping\"%s\"", key);
                        continue;
                    }
                    has_notifications = true;

                    notifications.reload_config ();

                    // Append the notifications widget to the box in the order of the provided list
                    box.append (notifications);
                    continue;
                }
                if (widget == null) {
                    continue;
                }

                // Note: Copies the value into the linked list
                widgets.append (widget);

                unowned Widgets.BaseWidget cloned_widget = widgets.last ().data;
                box.append (cloned_widget);
            }
        }

        /** Resets the UI positions */
        private void set_anchor () {
            PositionX pos_x = ConfigModel.instance.control_center_positionX;
            if (pos_x == PositionX.NONE) pos_x = ConfigModel.instance.positionX;
            PositionY pos_y = ConfigModel.instance.control_center_positionY;
            if (pos_y == PositionY.NONE) pos_y = ConfigModel.instance.positionY;

            if (swaync_daemon.use_layer_shell) {
                // Set the exlusive zone
                int exclusive_zone = ConfigModel.instance.control_center_exclusive_zone ? 0 : 100;
                GtkLayerShell.set_exclusive_zone (this, exclusive_zone);
                // Grabs the keyboard input until closed
                bool keyboard_shortcuts = ConfigModel.instance.keyboard_shortcuts;
                var mode = keyboard_shortcuts ?
                           GtkLayerShell.KeyboardMode.EXCLUSIVE :
                           GtkLayerShell.KeyboardMode.NONE;
                GtkLayerShell.set_keyboard_mode (this, mode);

                // Set layer
                GtkLayerShell.set_layer (
                    this, ConfigModel.instance.control_center_layer.to_layer ());

                // Set whether the control center should cover the whole screen or not
                bool cover_screen = ConfigModel.instance.layer_shell_cover_screen;
                if (cover_screen) {
                    GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, cover_screen);
                    GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, cover_screen);
                    GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, cover_screen);
                    GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, cover_screen);
                } else {
                    // Fallback to conventional positioning
                    switch (pos_x) {
                        case PositionX.LEFT:
                            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
                            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, false);
                            break;
                        case PositionX.CENTER:
                            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
                            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
                            break;
                        default:
                        case PositionX.RIGHT:
                            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, false);
                            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
                            break;
                    }
                    if (ConfigModel.instance.fit_to_screen) {
                        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
                    } else {
                        switch (pos_y) {
                            default:
                            case PositionY.TOP:
                                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, false);
                                break;
                            case PositionY.CENTER:
                                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
                                break;
                            case PositionY.BOTTOM:
                                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, false);
                                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
                                break;
                        }
                    }
                }
            }

            // Set the window margins
            window.set_margin_top (ConfigModel.instance.control_center_margin_top);
            window.set_margin_start (ConfigModel.instance.control_center_margin_left);
            window.set_margin_end (ConfigModel.instance.control_center_margin_right);
            window.set_margin_bottom (ConfigModel.instance.control_center_margin_bottom);

            // Anchor window to north/south edges as needed
            Gtk.Align align_x = Gtk.Align.END;
            switch (pos_x) {
                case PositionX.LEFT:
                    align_x = Gtk.Align.START;
                    break;
                case PositionX.CENTER:
                    align_x = Gtk.Align.CENTER;
                    break;
                default:
                case PositionX.RIGHT:
                    align_x = Gtk.Align.END;
                    break;
            }
            Gtk.Align align_y = Gtk.Align.START;
            switch (pos_y) {
                default:
                case PositionY.TOP:
                    align_y = Gtk.Align.START;
                    // Set cc widget position
                    notifications.set_list_is_reversed (false);
                    break;
                case PositionY.CENTER:
                    align_y = Gtk.Align.CENTER;
                    // Set cc widget position
                    notifications.set_list_is_reversed (false);
                    break;
                case PositionY.BOTTOM:
                    align_y = Gtk.Align.END;
                    // Set cc widget position
                    notifications.set_list_is_reversed (true);
                    break;
            }
            // Fit the ControlCenter to the monitor height
            if (ConfigModel.instance.fit_to_screen) align_y = Gtk.Align.FILL;
            // Set the ControlCenter alignment
            window.set_halign (align_x);
            window.set_valign (align_y);

            // Re-set the minimum size
            window.set_propagate_natural_height (
                ConfigModel.instance.control_center_height < 1
                || ConfigModel.instance.fit_to_screen);
            window.set_size_request (ConfigModel.instance.control_center_width,
                                  ConfigModel.instance.control_center_height);
            box.set_size_request (ConfigModel.instance.control_center_width,
                                  ConfigModel.instance.control_center_height);

            // Set the preferred monitor
            string ? monitor_name = ConfigModel.instance.control_center_preferred_output;
            if (this.monitor_name != null) {
                monitor_name = this.monitor_name;
            }
            set_monitor (Functions.try_get_monitor (monitor_name));
        }

        public uint notification_count () {
            return notifications.notification_count ();
        }

        public void close_all_notifications () {
            notifications.close_all_notifications ();
        }

        private void on_visibility_change () {
            // Updates all widgets on visibility change
            foreach (var widget in widgets) {
                widget.on_cc_visibility_change (visible);
            }

            if (this.visible) {
                add_css_class ("open");
            } else {
                remove_css_class ("open");
            }
            swaync_daemon.subscribe_v2 (notification_count (),
                                        noti_daemon.dnd,
                                        this.visible,
                                        swaync_daemon.inhibited);
        }

        public bool toggle_visibility () {
            var cc_visibility = !this.visible;
            set_visibility (cc_visibility);
            return cc_visibility;
        }

        public void set_visibility (bool visibility) {
            if (this.visible == visibility) return;
            if (visibility) {
                // Destroy the wl_surface to get a new "enter-monitor" signal
                ((Gtk.Widget) this).unrealize ();
            }
            this.set_visible (visibility);

            on_visibility_change ();
        }

        public void close_notification (uint32 id, bool dismiss) {
            notifications.close_notification (id, dismiss);
        }

        public void replace_notification (uint32 id, NotifyParams new_params) {
            notifications.replace_notification (id, new_params);
        }

        public void add_notification (NotifyParams param) {
            notifications.add_notification (param);
        }

        public bool get_visibility () {
            return this.visible;
        }

        public void set_monitor (Gdk.Monitor ? monitor) {
            this.monitor_name = monitor == null ? null : monitor.connector;
            GtkLayerShell.set_monitor (this, monitor);
        }
    }
}
