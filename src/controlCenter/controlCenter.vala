namespace SwayNotificationCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/controlCenter/controlCenter.ui")]
    public class ControlCenter : Gtk.ApplicationWindow {

        [GtkChild]
        unowned Gtk.ScrolledWindow scrolled_window;
        [GtkChild]
        unowned Gtk.Viewport viewport;
        [GtkChild]
        unowned Gtk.ListBox list_box;
        [GtkChild]
        unowned Gtk.Box box;

        private Gtk.Switch dnd_button;
        private Gtk.Button clear_all_button;

        private SwayncDaemon swaync_daemon;
        private NotiDaemon noti_daemon;

        private uint list_position = 0;

        private double last_upper = 0;
        private bool list_reverse = false;
        private Gtk.Align list_align = Gtk.Align.START;

        public ControlCenter (SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            this.swaync_daemon = swaync_daemon;
            this.noti_daemon = noti_daemon;

            if (!GtkLayerShell.is_supported ()) {
                stderr.printf ("GTKLAYERSHELL IS NOT SUPPORTED!\n");
                stderr.printf ("Swaync only works on Wayland!\n");
                stderr.printf ("If running waylans session, try running:\n");
                stderr.printf ("\tGDK_BACKEND=wayland swaync\n");
                Process.exit (1);
            }
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);

            viewport.size_allocate.connect (size_alloc);

            this.map.connect (() => {
                set_anchor ();
                // Wait until the layer has attached
                ulong id = 0;
                id = notify["has-toplevel-focus"].connect (() => {
                    disconnect (id);
                    unowned Gdk.Monitor monitor = null;
                    unowned Gdk.Window ? win = get_window ();
                    if (win != null) {
                        monitor = get_display ().get_monitor_at_window (win);
                    }
                    swaync_daemon.show_blank_windows (monitor);
                });
            });
            this.unmap.connect (swaync_daemon.hide_blank_windows);

            this.button_press_event.connect (blank_window_press);
            this.touch_event.connect (blank_window_press);

            // Only use release for closing notifications due to Escape key
            // sometimes being passed through to unfucused application
            // Ex: Firefox in a fullscreen YouTube video
            this.key_release_event.connect ((w, event_key) => {
                if (event_key.type == Gdk.EventType.KEY_RELEASE) {
                    switch (Gdk.keyval_name (event_key.keyval)) {
                        case "Escape":
                        case "Caps_Lock":
                            this.set_visibility (false);
                            return true;
                    }
                }
                return true;
            });

            this.key_press_event.connect ((w, event_key) => {
                if (event_key.type == Gdk.EventType.KEY_PRESS) {
                    var children = list_box.get_children ();
                    Notification noti = (Notification)
                                        list_box.get_focus_child ();
                    switch (Gdk.keyval_name (event_key.keyval)) {
                        case "Return":
                            if (noti != null) noti.click_default_action ();
                            break;
                        case "Delete":
                        case "BackSpace":
                            if (noti != null) {
                                if (children.length () == 0) break;
                                if (list_reverse &&
                                    children.first ().data != noti) {
                                    list_position--;
                                } else if (children.last ().data == noti) {
                                    if (list_position > 0) list_position--;
                                }
                                close_notification (noti.param.applied_id);
                            }
                            break;
                        case "C":
                            close_all_notifications ();
                            break;
                        case "D":
                            set_switch_dnd_state (!dnd_button.get_state ());
                            break;
                        case "Down":
                            if (list_position + 1 < children.length ()) {
                                ++list_position;
                            }
                            break;
                        case "Up":
                            if (list_position > 0) --list_position;
                            break;
                        case "Home":
                            list_position = 0;
                            break;
                        case "End":
                            list_position = children.length () - 1;
                            if (list_position == uint.MAX) list_position = 0;
                            break;
                        default:
                            // Pressing 1-9 to activate a notification action
                            for (int i = 0; i < 9; i++) {
                                uint keyval = Gdk.keyval_from_name (
                                    (i + 1).to_string ());
                                if (event_key.keyval == keyval) {
                                    if (noti != null) noti.click_alt_action (i);
                                    break;
                                }
                            }
                            break;
                    }
                    navigate_list (list_position);
                }
                return true;
            });

            clear_all_button = new Gtk.Button.with_label ("Clear All");
            clear_all_button.get_style_context ().add_class (
                "control-center-clear-all");
            clear_all_button.clicked.connect (close_all_notifications);
            this.box.add (new TopAction ("Notifications",
                                         clear_all_button,
                                         true));

            dnd_button = new Gtk.Switch () {
                state = noti_daemon.dnd,
            };
            dnd_button.get_style_context ().add_class ("control-center-dnd");
            dnd_button.state_set.connect ((widget, state) => {
                noti_daemon.dnd = state;
                return false;
            });
            this.box.add (new TopAction ("Do Not Disturb", dnd_button, false));
        }

        private bool blank_window_press (Gdk.Event event) {
            // Calculate if the clicked coords intersect the ControlCenter
            double x, y;
            event.get_coords (out x, out y);
            Gdk.Rectangle click_rectangle = Gdk.Rectangle () {
                width = 1,
                height = 1,
                x = (int) x,
                y = (int) y,
            };
            if (box.intersect (click_rectangle, null)) return true;
            try {
                swaync_daemon.set_visibility (false);
            } catch (Error e) {
                stderr.printf ("ControlCenter BlankWindow Click Error: %s\n",
                               e.message);
            }
            return true;
        }

        /** Resets the UI positions */
        private void set_anchor () {
            // Grabs the keyboard input until closed
            bool keyboard_shortcuts = ConfigModel.instance.keyboard_shortcuts;
#if HAVE_LATEST_GTK_LAYER_SHELL
            var mode = keyboard_shortcuts ?
                       GtkLayerShell.KeyboardMode.EXCLUSIVE :
                       GtkLayerShell.KeyboardMode.NONE;
            GtkLayerShell.set_keyboard_mode (this, mode);
#else
            GtkLayerShell.set_keyboard_interactivity (this, keyboard_shortcuts);
#endif
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);

            // Set the box margins
            box.set_margin_top (ConfigModel.instance.control_center_margin_top);
            box.set_margin_start (ConfigModel.instance.control_center_margin_left);
            box.set_margin_end (ConfigModel.instance.control_center_margin_right);
            box.set_margin_bottom (ConfigModel.instance.control_center_margin_bottom);

            // Anchor box to north/south edges as needed
            Gtk.Align align_x = Gtk.Align.END;
            switch (ConfigModel.instance.positionX) {
                case PositionX.LEFT:
                    align_x = Gtk.Align.START;
                    break;
                case PositionX.CENTER:
                    align_x = Gtk.Align.CENTER;
                    break;
                case PositionX.RIGHT:
                    align_x = Gtk.Align.END;
                    break;
            }
            Gtk.Align align_y = Gtk.Align.START;
            switch (ConfigModel.instance.positionY) {
                case PositionY.TOP:
                    align_y = Gtk.Align.START;
                    // Set cc widget position
                    list_reverse = false;
                    list_align = Gtk.Align.START;
                    this.box.set_child_packing (
                        scrolled_window, true, true, 0, Gtk.PackType.END);
                    break;
                case PositionY.BOTTOM:
                    align_y = Gtk.Align.END;
                    // Set cc widget position
                    list_reverse = true;
                    list_align = Gtk.Align.END;
                    this.box.set_child_packing (
                        scrolled_window, true, true, 0, Gtk.PackType.START);
                    break;
            }
            // Fit the ControlCenter to the monitor height
            if (ConfigModel.instance.fit_to_screen) align_y = Gtk.Align.FILL;
            // Set the ControlCenter alignment
            box.set_halign (align_x);
            box.set_valign (align_y);

            list_box.set_valign (list_align);
            list_box.set_sort_func ((w1, w2) => {
                var a = (Notification) w1;
                var b = (Notification) w2;
                if (a == null || b == null) return 0;
                // Sort the list in reverse if needed
                if (a.param.time == b.param.time) return 0;
                int val = list_reverse ? 1 : -1;
                return a.param.time > b.param.time ? val : val * -1;
            });

            // Always set the size request in all events.
            box.set_size_request (ConfigModel.instance.control_center_width,
                                  ConfigModel.instance.control_center_height);
        }

        private void size_alloc () {
            var adj = viewport.vadjustment;
            double upper = adj.get_upper ();
            if (last_upper < upper) {
                scroll_to_start (list_reverse);
            }
            last_upper = upper;
        }

        private void scroll_to_start (bool reverse) {
            Gtk.ScrollType scroll_type = Gtk.ScrollType.START;
            if (reverse) {
                scroll_type = Gtk.ScrollType.END;
            }
            scrolled_window.scroll_child (scroll_type, false);
        }

        public uint notification_count () {
            return list_box.get_children ().length ();
        }

        public void close_all_notifications () {
            foreach (var w in list_box.get_children ()) {
                Notification noti = (Notification) w;
                if (noti != null) noti.close_notification (false);
            }

            try {
                swaync_daemon.subscribe (notification_count (),
                                         swaync_daemon.get_dnd (),
                                         get_visibility ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }

            if (ConfigModel.instance.hide_on_clear) {
                this.set_visibility (false);
            }
        }

        private void navigate_list (uint i) {
            var widget = list_box.get_children ().nth_data (i);
            if (widget != null) {
                list_box.set_focus_child (widget);
                widget.grab_focus ();
            }
        }

        private void on_visibility_change () {
            if (this.visible) {
                // Focus the first notification
                list_position = list_reverse ?
                                (list_box.get_children ().length () - 1) : 0;
                if (list_position == uint.MAX) list_position = 0;

                list_box.grab_focus ();
                navigate_list (list_position);
                foreach (var w in list_box.get_children ()) {
                    var noti = (Notification) w;
                    if (noti != null) noti.set_time ();
                }
            }
            swaync_daemon.subscribe (notification_count (),
                                     noti_daemon.dnd,
                                     this.visible);
        }

        public void set_switch_dnd_state (bool state) {
            if (this.dnd_button.state != state) this.dnd_button.state = state;
        }

        public bool toggle_visibility () {
            var cc_visibility = !this.visible;
            if (this.visible != cc_visibility) {
                this.set_visible (cc_visibility);
                on_visibility_change ();
            }
            return cc_visibility;
        }

        public void set_visibility (bool visibility) {
            if (this.visible == visibility) return;
            this.set_visible (visibility);
            on_visibility_change ();
        }

        public void close_notification (uint32 id, bool replaces = false) {
            foreach (var w in list_box.get_children ()) {
                var noti = (Notification) w;
                if (noti != null && noti.param.applied_id == id) {
                    if (replaces) {
                        noti.remove_noti_timeout ();
                        noti.destroy ();
                    } else {
                        noti.close_notification (false);
                        list_box.remove (w);
                    }
                    break;
                }
            }
        }

        public void add_notification (NotifyParams param,
                                      NotiDaemon noti_daemon) {
            var noti = new Notification.regular (param, noti_daemon);
            noti.grab_focus.connect ((w) => {
                uint i = list_box.get_children ().index (w);
                if (list_position != uint.MAX && list_position != i) {
                    list_position = i;
                }
            });
            noti.set_time ();
            list_box.add (noti);
            scroll_to_start (list_reverse);
            try {
                swaync_daemon.subscribe (notification_count (),
                                         swaync_daemon.get_dnd (),
                                         get_visibility ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        public bool get_visibility () {
            return this.visible;
        }

        /** Forces each notification EventBox to reload its style_context #27 */
        public void reload_notifications_style () {
            foreach (var c in list_box.get_children ()) {
                Notification noti = (Notification) c;
                if (noti != null) noti.reload_style_context ();
            }
        }
    }
}
