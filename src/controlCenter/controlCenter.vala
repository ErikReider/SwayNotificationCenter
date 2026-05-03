namespace SwayNotificationCenter {
    [GtkTemplate (ui = "/org/erikreider/swaync/ui/control_center.ui")]
    public class ControlCenter : Gtk.ApplicationWindow {
        [GtkChild]
        unowned Gtk.ScrolledWindow window;
        [GtkChild]
        unowned IterBox box;

        private Gtk.GestureClick blank_window_gesture;
        private bool blank_window_down = false;
        private bool blank_window_in = false;

        private Gtk.EventControllerKey key_controller;

        private Ext.BackgroundEffect.Surface *bg_effect = null;
        private int last_blur_x = -1;
        private int last_blur_y = -1;
        private int last_blur_w = -1;
        private int last_blur_h = -1;
        private int last_blur_radius = -1;

        /** Unsorted list of copies of all notifications */
        private List<unowned Widgets.BaseWidget> widgets;
        private const string[] DEFAULT_WIDGETS = { "title", "dnd", "notifications" };

        private string ?monitor_name = null;

        public ControlCenter () {
            Object (css_name: "blankwindow");

            widgets = new List<unowned Widgets.BaseWidget> ();
            widgets.append (notifications_widget);

            if (app.use_layer_shell) {
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
                    warn_if_reached ();
                    return;
                }

                ulong id = 0;
                id = surface.enter_monitor.connect ((monitor) => {
                    surface.disconnect (id);
                    debug ("ControlCenter mapped on monitor: %s",
                           Functions.monitor_to_string (monitor));
                    app.show_blank_windows (monitor);

                    update_blur_effect ();
                });
            });
            this.unmap.connect (() => {
                debug ("ControlCenter un-mapped");
                app.hide_blank_windows ();
                destroy_blur_effect ();
            });

            /*
             * Handling of bank window presses (pressing outside of Control Center)
             */
            blank_window_gesture = new Gtk.GestureClick ();
            ((Gtk.Widget) this).add_controller (blank_window_gesture);
            blank_window_gesture.touch_only = false;
            blank_window_gesture.exclusive = true;
            blank_window_gesture.button = Gdk.BUTTON_PRIMARY;
            blank_window_gesture.propagation_phase = Gtk.PropagationPhase.BUBBLE;
            blank_window_gesture.pressed.connect ((n_press, x, y) => {
                // Calculate if the clicked coords intersect the Control Center
                Graphene.Point click_point = Graphene.Point ()
                     .init ((float) x, (float) y);
                Graphene.Rect ?bounds = null;
                window.compute_bounds (this, out bounds);
                blank_window_in = !(bounds != null && bounds.contains_point (click_point));
                blank_window_down = true;
            });
            blank_window_gesture.released.connect ((n_press, x, y) => {
                // Emit released
                if (!blank_window_down) {
                    return;
                }
                blank_window_down = false;
                if (blank_window_in) {
                    set_visibility (false);
                }

                if (blank_window_gesture.get_current_sequence () == null) {
                    blank_window_in = false;
                }
            });
            blank_window_gesture.update.connect ((gesture, sequence) => {
                Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
                if (sequence != gesture_single.get_current_sequence ()) {
                    return;
                }
                // Calculate if the clicked coords intersect the Control Center
                double x, y;
                gesture.get_point (sequence, out x, out y);
                Graphene.Point click_point = Graphene.Point ()
                     .init ((float) x, (float) y);
                Graphene.Rect ?bounds = null;
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
                update_blur_effect ();
            });
        }

        ~ControlCenter () {
            destroy_blur_effect ();
        }

        private void key_released_event_cb (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (this.get_focus () is Gtk.Entry) {
                switch (Gdk.keyval_name (keyval)) {
                    case "Escape" :
                        this.set_focus (null);
                        return;
                }
                return;
            }
            switch (Gdk.keyval_name (keyval)) {
                case "Escape" :
                case "Caps_Lock":
                    this.set_visibility (false);
                    return;
            }
        }

        private bool key_press_event_cb (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (get_focus () is Gtk.Editable) {
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
                    return notifications_widget.key_press_event_cb (keyval, keycode, state);
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
                // Except for notifications. Otherwise we'd lose notifications
                if (widget is Widgets.Notifications) {
                    return;
                }
                widgets.remove (widget);
            });

            string[] w = ConfigModel.instance.widgets.data;
            if (w.length == 0) {
                w = DEFAULT_WIDGETS;
            }

            // Add the notifications widget if not found in the list
            if (!("notifications" in w)) {
                warning ("Notification widget not included in \"widgets\" config. " +
                         "Using default bottom position");
                w += "notifications";
            }
            bool has_notifications = false;
            foreach (string key in w) {
                // Add the widget if it is valid
                bool is_notifications;
                Widgets.BaseWidget ?widget = Widgets.get_widget_from_key (
                    key, out is_notifications);

                if (is_notifications) {
                    if (has_notifications) {
                        warning ("Cannot have multiple \"notifications\" widgets! Skipping\"%s\"",
                                 key);
                        continue;
                    }
                    has_notifications = true;

                    notifications_widget.reload_config ();

                    // Append the notifications widget to the box in the order of the provided list
                    box.append (notifications_widget);
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
            debug ("ControlCenter set_anchor");
            PositionX pos_x = ConfigModel.instance.control_center_positionX;
            if (pos_x == PositionX.NONE) {
                pos_x = ConfigModel.instance.positionX;
            }
            PositionY pos_y = ConfigModel.instance.control_center_positionY;
            if (pos_y == PositionY.NONE) {
                pos_y = ConfigModel.instance.positionY;
            }

            if (app.use_layer_shell) {
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
                        case PositionX.LEFT :
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

                // Set the preferred monitor
                string ?monitor_name = ConfigModel.instance.control_center_preferred_output;
                if (this.monitor_name != null) {
                    monitor_name = this.monitor_name;
                }
                set_monitor (Functions.try_get_monitor (monitor_name));
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
                    notifications_widget.set_list_is_reversed (false);
                    break;
                case PositionY.CENTER:
                    align_y = Gtk.Align.CENTER;
                    // Set cc widget position
                    notifications_widget.set_list_is_reversed (false);
                    break;
                case PositionY.BOTTOM:
                    align_y = Gtk.Align.END;
                    // Set cc widget position
                    notifications_widget.set_list_is_reversed (true);
                    break;
            }
            // Fit the ControlCenter to the monitor height
            if (ConfigModel.instance.fit_to_screen) {
                align_y = Gtk.Align.FILL;
            }
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
        }

        public bool toggle_visibility () {
            var cc_visibility = !this.visible;
            set_visibility (cc_visibility);
            return cc_visibility;
        }

        public void set_visibility (bool visibility) {
            if (this.visible == visibility) {
                return;
            }
            destroy_blur_effect ();

            // Destroy the wl_surface to get a new "enter-monitor" signal and
            // fixes issues where keyboard shortcuts stop working after clearing
            // all notifications.
            ((Gtk.Widget) this).unrealize ();

            this.set_visible (visibility);

            // Updates all widgets on visibility change
            foreach (var widget in widgets) {
                widget.on_cc_visibility_change (visible);
            }

            if (this.visible) {
                add_css_class ("open");
            } else {
                remove_css_class ("open");
            }
            swaync_daemon.emit_subscribe ();
        }

        public inline bool get_visibility () {
            return this.visible;
        }

        public void set_monitor (Gdk.Monitor ?monitor) {
            debug ("Setting monitor for ControlCenter: %s",
                   Functions.monitor_to_string (monitor) ?? "Monitor Picked by Compositor");
            this.monitor_name = monitor == null ? null : monitor.connector;
            GtkLayerShell.set_monitor (this, monitor);
        }

        protected override void size_allocate (int w, int h, int baseline) {
            base.size_allocate (w, h, baseline);
            update_blur_effect ();
        }

        public void update_blur_effect () {
            if (!ConfigModel.instance.background_blur
                || !app.background_effect.blur_available) {
                destroy_blur_effect ();
                return;
            }

            unowned Gdk.Surface ?gdk_surface = get_surface ();
            if (gdk_surface == null) {
                return;
            }
            unowned Wl.Surface wlsurface = Functions.get_wl_surface (gdk_surface);
            if (wlsurface == null) {
                return;
            }

            if (bg_effect == null) {
                bg_effect = app.background_effect.create_effect (wlsurface);
                if (bg_effect == null) {
                    return;
                }
            }

            Graphene.Rect win_bounds;
            if (!window.compute_bounds (this, out win_bounds)) {
                return;
            }

            double surface_x, surface_y;
            ((Gtk.Native) this).get_surface_transform (out surface_x, out surface_y);

            int x = (int) win_bounds.get_x () + (int) surface_x;
            int y = (int) win_bounds.get_y () + (int) surface_y;
            int width = (int) win_bounds.get_width ();
            int height = (int) win_bounds.get_height ();
            if (width < 2 || height < 2) {
                return;
            }

            int radius = BackgroundEffectHelper.get_widget_border_radius (window);

            if (x == last_blur_x && y == last_blur_y
                && width == last_blur_w && height == last_blur_h
                && radius == last_blur_radius) {
                return;
            }
            last_blur_x = x;
            last_blur_y = y;
            last_blur_w = width;
            last_blur_h = height;
            last_blur_radius = radius;

            app.background_effect.set_blur_region_rounded (bg_effect, x, y,
                                                           width, height, radius);
            unowned Gdk.Surface ?s = get_surface ();
            if (s != null) {
                s.queue_render ();
            }
        }

        private void destroy_blur_effect () {
            if (bg_effect != null) {
                app.background_effect.destroy_effect (bg_effect);
                bg_effect = null;
                queue_blur_commit ();
            }
            invalidate_blur_cache ();
        }

        private void queue_blur_commit () {
            unowned Gdk.Surface ?surface = get_surface ();
            if (surface != null) {
                surface.queue_render ();
            }
        }

        private inline void invalidate_blur_cache () {
            last_blur_w = -1;
        }
    }
}
