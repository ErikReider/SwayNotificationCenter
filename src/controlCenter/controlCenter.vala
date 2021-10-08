namespace SwayNotificatonCenter {
    [DBus (name = "org.erikreider.swaync.cc")]
    public class CcDaemon : Object {
        private ControlCenterWidget cc = null;
        private DBusInit dbusInit;

        public CcDaemon (DBusInit dbusInit) {
            this.dbusInit = dbusInit;
            cc = new ControlCenterWidget (this, dbusInit);

            dbusInit.notiDaemon.on_dnd_toggle.connect ((dnd) => {
                try {
                    cc.set_switch_dnd_state (dnd);
                    subscribe (notification_count (), dnd);
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
            });

            // Update on start
            try {
                subscribe (notification_count (), get_dnd ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        public signal void subscribe (uint count, bool dnd);

        public bool get_visibility () throws DBusError, IOError {
            return cc.visible;
        }

        public void close_all_notifications () throws DBusError, IOError {
            cc.close_all_notifications ();
            dbusInit.notiDaemon.close_all_notifications ();
        }

        public uint notification_count () throws DBusError, IOError {
            return cc.notification_count ();
        }

        public void toggle_visibility () throws DBusError, IOError {
            if (cc.toggle_visibility ()) {
                dbusInit.notiDaemon.set_noti_window_visibility (false);
            }
        }

        public bool toggle_dnd () throws DBusError, IOError {
            return dbusInit.notiDaemon.toggle_dnd ();
        }

        public void set_dnd (bool state) throws DBusError, IOError {
            dbusInit.notiDaemon.set_dnd (state);
        }

        public bool get_dnd () throws DBusError, IOError {
            return dbusInit.notiDaemon.get_dnd ();
        }

        public void add_notification (NotifyParams param) throws DBusError, IOError {
            cc.add_notification (param, dbusInit.notiDaemon);
        }

        public void close_notification (uint32 id) throws DBusError, IOError {
            cc.close_notification (id);
        }
    }

    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/controlCenter/controlCenter.ui")]
    private class ControlCenterWidget : Gtk.ApplicationWindow {

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

        public ControlCenterWidget (CcDaemon cc_daemon, DBusInit dbusInit) {
            this.cc_daemon = cc_daemon;
            GtkLayerShell.init_for_window (this);
            // Grabs the keyboard input until closed
#if HAVE_LATEST_GTK_LAYER_SHELL
            GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.ON_DEMAND);
#else
            GtkLayerShell.set_keyboard_interactivity (this, true);
#endif
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);

            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            switch (dbusInit.configModel.positionX) {
                case PositionX.LEFT:
                    GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
                    break;
                default:
                    GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
                    break;
            }
            if (dbusInit.configModel.positionY == PositionY.BOTTOM) {
                list_reverse = true;
                list_align = Gtk.Align.END;
                this.box.set_child_packing (scrolled_window, true, true, 0, Gtk.PackType.START);
            }
            viewport.size_allocate.connect (() => size_alloc (list_reverse));
            list_box.set_valign (list_align);
            list_box.set_sort_func ((w1, w2) => {
                var a = (Notification) w1;
                var b = (Notification) w2;
                if (a == null || b == null) return 0;
                // Sort the list in reverse if needed
                int val1 = list_reverse ? 1 : -1;
                int val2 = list_reverse ? -1 : 1;
                return a.param._time > b.param._time ? val1 : val2;
            });

            this.key_press_event.connect ((w, event_key) => {
                if (event_key.type == Gdk.EventType.KEY_PRESS) {
                    if (event_key.keyval == Gdk.keyval_from_name ("Escape") ||
                        event_key.keyval == Gdk.keyval_from_name ("Caps_Lock")) {
                        toggle_visibility ();
                        return true;
                    } else if (event_key.keyval == Gdk.keyval_from_name ("Return")) {
                        Notification noti = (Notification) list_box.get_focus_child ();
                        if (noti != null) noti.click_default_action ();
                    } else if (event_key.keyval == Gdk.keyval_from_name ("Delete") ||
                               event_key.keyval == Gdk.keyval_from_name ("BackSpace")) {
                        Notification noti = (Notification) list_box.get_focus_child ();
                        if (noti != null) {
                            if (list_reverse &&
                                list_box.get_children ().first ().data != noti) {
                                list_position--;
                            } else if (list_box.get_children ().last ().data == noti) {
                                if (list_position > 0) list_position--;
                            }
                            close_notification (noti.param.applied_id);
                        }
                    } else if (event_key.keyval == Gdk.keyval_from_name ("C")) {
                        close_all_notifications ();
                    } else if (event_key.keyval == Gdk.keyval_from_name ("D")) {
                        set_switch_dnd_state (!this.dnd_button.get_state ());
                    } else if (event_key.keyval == Gdk.keyval_from_name ("Down")) {
                        if (list_position + 1 < list_box.get_children ().length ()) {
                            ++list_position;
                        }
                    } else if (event_key.keyval == Gdk.keyval_from_name ("Up")) {
                        if (list_position > 0) --list_position;
                    } else if (event_key.keyval == Gdk.keyval_from_name ("Home")) {
                        list_position = 0;
                    } else if (event_key.keyval == Gdk.keyval_from_name ("End")) {
                        list_position = list_box.get_children ().length () - 1;
                        if (list_position == uint.MAX) list_position = 0;
                    } else {
                        for (int i = 0; i < 9; i++) {
                            uint keyval = Gdk.keyval_from_name ((i + 1).to_string ());
                            if (event_key.keyval == keyval) {
                                Notification noti = (Notification) list_box.get_focus_child ();
                                if (noti != null) noti.click_alt_action (i);
                                break;
                            }
                        }
                    }
                    navigate_list (list_position);
                }
                return true;
            });

            clear_all_button = new Gtk.Button.with_label ("Clear All");
            clear_all_button.get_style_context ().add_class ("control-center-clear-all");
            clear_all_button.clicked.connect (close_all_notifications);
            this.box.add (new TopAction ("Notifications", clear_all_button, true));

            dnd_button = new Gtk.Switch ();
            dnd_button.get_style_context ().add_class ("control-center-dnd");
            dnd_button.state_set.connect ((widget, state) => {
                try {
                    cc_daemon.set_dnd (state);
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
                return false;
            });
            this.box.add (new TopAction ("Do Not Disturb", dnd_button, false));
        }

        private void size_alloc (bool reverse) {
            var adj = viewport.vadjustment;
            double upper = adj.get_upper ();
            if (last_upper < upper) {
                scroll_to_start (reverse);
            }
            last_upper = upper;
        }

        private void scroll_to_start (bool reverse) {
            var adj = viewport.vadjustment;
            double val = adj.get_lower ();
            list_position = 0;
            if (reverse) {
                val = adj.get_upper ();
                list_position = list_reverse ? (list_box.get_children ().length () - 1) : 0;
                if (list_position == uint.MAX) list_position = -1;
            }
            adj.set_value (val);
            navigate_list (list_position);
        }

        public uint notification_count () {
            return list_box.get_children ().length ();
        }

        public void close_all_notifications () {
            foreach (var w in list_box.get_children ()) {
                list_box.remove (w);
            }

            try {
                cc_daemon.subscribe (notification_count (), cc_daemon.get_dnd ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        private void navigate_list (uint i) {
            var widget = list_box.get_children ().nth_data (i);
            if (widget != null) {
                list_box.set_focus_child (widget);
                widget.grab_focus ();
            }
        }

        public void set_switch_dnd_state (bool state) {
            if (this.dnd_button.state != state) this.dnd_button.state = state;
        }

        public bool toggle_visibility () {
            var cc_visibility = !this.visible;
            this.set_visible (cc_visibility);

            if (cc_visibility) {
                // Focus the first notification
                list_position = list_reverse ? (list_box.get_children ().length () - 1) : 0;
                if (list_position == uint.MAX) list_position = 0;

                list_box.grab_focus ();
                navigate_list (list_position);
                foreach (var w in list_box.get_children ()) {
                    var noti = (Notification) w;
                    if (noti != null) noti.set_time ();
                }
            }
            return cc_visibility;
        }

        public void close_notification (uint32 id) {
            foreach (var w in list_box.get_children ()) {
                if (((Notification) w).param.applied_id == id) {
                    list_box.remove (w);
                    break;
                }
            }
            try {
                cc_daemon.subscribe (notification_count (), cc_daemon.get_dnd ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        public void add_notification (NotifyParams param, NotiDaemon notiDaemon) {
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
                cc_daemon.subscribe (notification_count (), cc_daemon.get_dnd ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }
    }
}
