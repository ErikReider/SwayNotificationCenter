namespace SwayNotificatonCenter {
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

        private CcDaemon cc_daemon;

        private uint list_position = 0;

        private double last_upper = 0;
        private bool list_reverse = false;
        private Gtk.Align list_align = Gtk.Align.START;

        public ControlCenter (CcDaemon cc_daemon) {
            this.cc_daemon = cc_daemon;

            GtkLayerShell.init_for_window (this);
            this.set_anchor ();

            viewport.size_allocate.connect (size_alloc);

            this.key_press_event.connect ((w, event_key) => {
                if (event_key.type == Gdk.EventType.KEY_PRESS) {
                    var children = list_box.get_children ();
                    Notification noti = (Notification)
                                        list_box.get_focus_child ();
                    switch (Gdk.keyval_name (event_key.keyval)) {
                        case "Escape":
                        case "Caps_Lock":
                            toggle_visibility ();
                            return true;
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

            dnd_button = new Gtk.Switch ();
            dnd_button.get_style_context ().add_class ("control-center-dnd");
            dnd_button.state_set.connect ((widget, state) => {
                try {
                    this.cc_daemon.set_dnd (state);
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
                return false;
            });
            this.box.add (new TopAction ("Do Not Disturb", dnd_button, false));
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

            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            switch (ConfigModel.instance.positionX) {
                case PositionX.LEFT:
                    GtkLayerShell.set_anchor (this,
                                              GtkLayerShell.Edge.RIGHT,
                                              false);
                    GtkLayerShell.set_anchor (this,
                                              GtkLayerShell.Edge.LEFT,
                                              true);
                    break;
                case PositionX.CENTER:
                    GtkLayerShell.set_anchor (this,
                                              GtkLayerShell.Edge.RIGHT,
                                              false);
                    GtkLayerShell.set_anchor (this,
                                              GtkLayerShell.Edge.LEFT,
                                              false);
                    break;
                default:
                    GtkLayerShell.set_anchor (this,
                                              GtkLayerShell.Edge.LEFT,
                                              false);
                    GtkLayerShell.set_anchor (this,
                                              GtkLayerShell.Edge.RIGHT,
                                              true);
                    break;
            }
            switch (ConfigModel.instance.positionY) {
                case PositionY.BOTTOM:
                    list_reverse = true;
                    list_align = Gtk.Align.END;
                    this.box.set_child_packing (
                        scrolled_window, true, true, 0, Gtk.PackType.START);
                    break;
                case PositionY.TOP:
                    list_reverse = false;
                    list_align = Gtk.Align.START;
                    this.box.set_child_packing (
                        scrolled_window, true, true, 0, Gtk.PackType.END);
                    break;
            }

            list_box.set_valign (list_align);
            list_box.set_sort_func ((w1, w2) => {
                var a = (Notification) w1;
                var b = (Notification) w2;
                if (a == null || b == null) return 0;
                // Sort the list in reverse if needed
                int val1 = list_reverse ? 1 : -1;
                int val2 = list_reverse ? -1 : 1;
                return a.param.time > b.param.time ? val1 : val2;
            });
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
            const bool horizontal_scroll = false;
            Gtk.ScrollType scroll_type = Gtk.ScrollType.START;
            if (reverse) {
                scroll_type = Gtk.ScrollType.END;
            }
            scrolled_window.scroll_child (scroll_type, horizontal_scroll);
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
                cc_daemon.subscribe (
                    notification_count (), cc_daemon.get_dnd ());
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
                // Reload the settings from config
                this.set_anchor ();
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

        public void close_notification (uint32 id) {
            foreach (var w in list_box.get_children ()) {
                var noti = (Notification) w;
                if (noti != null && noti.param.applied_id == id) {
                    noti.close_notification (false);
                    list_box.remove (w);
                    break;
                }
            }
            try {
                cc_daemon.subscribe (
                    notification_count (), cc_daemon.get_dnd ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        public void add_notification (NotifyParams param,
                                      NotiDaemon notiDaemon) {
            var noti = new Notification (param, notiDaemon);
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
                cc_daemon.subscribe (
                    notification_count (), cc_daemon.get_dnd ());
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
