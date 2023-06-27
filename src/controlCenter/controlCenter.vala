namespace SwayNotificationCenter {
    public class ControlCenter : BlankWindow {
        // TODO: Replace with Gtk ListView?
        IterBox widgets_box = new IterBox (Gtk.Orientation.VERTICAL, 0);

        private Gtk.EventControllerKey event_kb;

        private unowned NotiDaemon noti_daemon;

        private Widgets.Notifications notification_widget
            = new Widgets.Notifications (NotificationType.CONTROL_CENTER);
        private const string[] DEFAULT_WIDGETS = { "title", "dnd", "notifications" };

        public ControlCenter (SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (swaync_daemon);
            this.noti_daemon = noti_daemon;

            // Setup window
            this.vexpand = true;
            this.halign = Gtk.Align.FILL;
            this.valign = Gtk.Align.FILL;

            set_child (widgets_box);
            widgets_box.set_hexpand (true);
            widgets_box.set_halign (Gtk.Align.FILL);
            widgets_box.add_css_class ("control-center");

            this.swaync_daemon.reloading_css.connect (reload_notifications_style);

            this.map.connect_after (() => {
                // Wait until the layer has attached
                unowned Gdk.Surface surface = get_surface ();
                if (!(surface is Gdk.Surface)) return;
                ulong id = 0;
                id = surface.enter_monitor.connect ((surface, monitor) => {
                    surface.disconnect (id);
                    swaync_daemon.show_empty_windows (monitor);
                });
            });
            this.unmap.connect (swaync_daemon.hide_empty_windows);

            /*
             * Handling of keyboard shortcuts
             */
            ((Gtk.Widget) this).add_controller (event_kb = new Gtk.EventControllerKey () {
                propagation_phase = Gtk.PropagationPhase.CAPTURE,
            });

            // Only use release for closing notifications due to Escape key
            // sometimes being passed through to unfucused application
            // Ex: Firefox in a fullscreen YouTube video
            event_kb.key_released.connect ((keyval, keycode, state) => {
                print ("FOCUS: %s\n", this.get_focus ().name);
                if (this.get_focus () is Gtk.Text) {
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
                return;
            });

            // event_controller_key.key_pressed.connect ((keyval, keycode, state) => {
            //     if (this.get_focus () is Gtk.Entry) return false;
            //     var children = list_box.get_children ();
            //     Notification noti = (Notification)
            //                         list_box.get_focus_child ();
            //     switch (Gdk.keyval_name (event_key.keyval)) {
            //         case "Return":
            //             if (noti != null) noti.click_default_action ();
            //             break;
            //         case "Delete":
            //         case "BackSpace":
            //             if (noti != null) {
            //                 if (children.length () == 0) break;
            //                 if (list_reverse &&
            //                     children.first ().data != noti) {
            //                     list_position--;
            //                 } else if (children.last ().data == noti) {
            //                     if (list_position > 0) list_position--;
            //                 }
            //                 close_notification (noti.param.applied_id);
            //             }
            //             break;
            //         case "C":
            //             close_all_notifications ();
            //             break;
            //         case "D":
            //             try {
            //                 swaync_daemon.toggle_dnd ();
            //             } catch (Error e) {
            //                 error ("Error: %s\n", e.message);
            //             }
            //             break;
            //         case "Down":
            //             if (list_position + 1 < children.length ()) {
            //                 ++list_position;
            //             }
            //             break;
            //         case "Up":
            //             if (list_position > 0) --list_position;
            //             break;
            //         case "Home":
            //             list_position = 0;
            //             break;
            //         case "End":
            //             list_position = children.length () - 1;
            //             if (list_position == uint.MAX) list_position = 0;
            //             break;
            //         default:
            //             // Pressing 1-9 to activate a notification action
            //             for (int i = 0; i < 9; i++) {
            //                 uint keyval = Gdk.keyval_from_name (
            //                     (i + 1).to_string ());
            //                 if (event_key.keyval == keyval) {
            //                     if (noti != null) noti.click_alt_action (i);
            //                     break;
            //                 }
            //             }
            //             break;
            //     }
            //     navigate_list (list_position);
            //     return false;
            // });

            add_widgets ();
        }

        /** Adds all custom widgets. Removes previous widgets */
        public void add_widgets () {
            // Remove all widgets
            foreach (var widget in widgets_box.get_children ()) {
                widgets_box.remove (widget);
            }

            string[] w = ConfigModel.instance.widgets.data;
            if (w.length == 0) w = DEFAULT_WIDGETS;
            bool has_notification = false;
            foreach (string key in w) {
                // Reposition the scrolled_window
                // TODO: REDO with notifications
                if (key == "notifications") {
                    has_notification = true;
                    widgets_box.append (notification_widget);
                    // uint pos = widgets_box.get_children ().length ();
                    // TODO: pos should be reduced by 1
                    // widgets_box.reorder_child_after (notifications, (int) (pos > 0 ? --pos : 0));
                    continue;
                }
                // Add the widget if it is valid
                Widgets.BaseWidget ? widget = Widgets.get_widget_from_key (
                    key, swaync_daemon, noti_daemon);
                if (widget == null) continue;
                widgets_box.append (widget);
            }
            if (!has_notification) {
                warning ("Notification widget not included in \"widgets\" config. Using default bottom position");
                widgets_box.append (notification_widget);
            }
        }

        public override Graphene.Rect? ignore_bounds () {
            Graphene.Rect ? bounds = null;
            bool result = widgets_box.compute_bounds (this, out bounds);
            return result ? bounds : null;
        }

        /** Resets the UI positions */
        public override void set_custom_options () {
            if (swaync_daemon.use_layer_shell) {
                // Grabs the keyboard input until closed
                bool keyboard_shortcuts = ConfigModel.instance.keyboard_shortcuts;
                var mode = keyboard_shortcuts ?
                           GtkLayerShell.KeyboardMode.EXCLUSIVE :
                           GtkLayerShell.KeyboardMode.NONE;
                GtkLayerShell.set_keyboard_mode (this, mode);
            }

            // Set the box margins
            widgets_box.set_margin_top (ConfigModel.instance.control_center_margin_top);
            widgets_box.set_margin_start (ConfigModel.instance.control_center_margin_left);
            widgets_box.set_margin_end (ConfigModel.instance.control_center_margin_right);
            widgets_box.set_margin_bottom (ConfigModel.instance.control_center_margin_bottom);

            // Anchor box to north/south edges as needed
            Gtk.Align align_x = Gtk.Align.END;
            PositionX pos_x = ConfigModel.instance.control_center_positionX;
            if (pos_x == PositionX.NONE) pos_x = ConfigModel.instance.positionX;
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
            PositionY pos_y = ConfigModel.instance.control_center_positionY;
            if (pos_y == PositionY.NONE) pos_y = ConfigModel.instance.positionY;
            switch (pos_y) {
                default:
                case PositionY.TOP:
                    align_y = Gtk.Align.START;
                    break;
                case PositionY.CENTER:
                    align_y = Gtk.Align.CENTER;
                    break;
                case PositionY.BOTTOM:
                    align_y = Gtk.Align.END;
                    break;
            }

            // Refresh the positioning of the notifications list
            notification_widget.set_list_orientation ();

            // Fit the ControlCenter to the monitor height
            if (ConfigModel.instance.fit_to_screen) align_y = Gtk.Align.FILL;
            // Set the ControlCenter alignment
            widgets_box.set_halign (align_x);
            widgets_box.set_valign (align_y);

            // Always set the size request in all events.
            widgets_box.set_size_request (ConfigModel.instance.control_center_width,
                                          ConfigModel.instance.control_center_height);
        }

        public uint notification_count () {
            return notification_widget.notification_count;
        }

        public void close_all_notifications () {
            notification_widget.close_all_notifications ();
            try {
                swaync_daemon.subscribe_v2 (notification_count (),
                                         swaync_daemon.get_dnd (),
                                         get_visibility (),
                                         swaync_daemon.inhibited);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }

            if (ConfigModel.instance.hide_on_clear) {
                this.set_visibility (false);
            }
        }

        // private void navigate_list (uint i) {
        //     var widget = (Notification) list_model.get_object (i);
        //     if (widget != null) {
        //         notification_list.set_focus_child (widget);
        //         widget.grab_focus ();
        //     }
        // }

        private void on_visibility_change () {
            // Updates all widgets on visibility change
            foreach (var widget in widgets_box.get_children ()) {
                if (widget is Widgets.BaseWidget) {
                    widget.on_cc_visibility_change (visible);
                }
            }

            if (this.visible) {
                notification_widget.navigate_to_start ();
                notification_widget.refresh_notifications_time ();
            }
            swaync_daemon.subscribe_v2 (notification_count (),
                                     noti_daemon.dnd,
                                     this.visible,
                                     swaync_daemon.inhibited);
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
            notification_widget.close_notification (id, replaces);
        }

        // FIX LARGE NOTIFICATIONS not scaling
        public void add_notification (NotifyParams param,
                                      NotiDaemon noti_daemon) {
            notification_widget.add_notification (param, noti_daemon);
            try {
                swaync_daemon.subscribe_v2 (notification_count (),
                                         swaync_daemon.get_dnd (),
                                         get_visibility (),
                                         swaync_daemon.inhibited);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        public bool get_visibility () {
            return this.visible;
        }

        /** Forces each notification EventBox to reload its style_context #27 */
        // TODO: Needed?
        private void reload_notifications_style () {
            // Functions.widget_children_foreach (list_box, (c) => {
            //     Notification noti = (Notification) c;
            //     if (noti != null) noti.reload_style_context ();
            //     return Source.CONTINUE;
            // });
        }
    }
}
