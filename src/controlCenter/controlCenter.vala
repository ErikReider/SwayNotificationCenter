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

        public bool reload_css () throws Error {
            return Functions.load_css (dbusInit.style_path);
        }

        public void reload_config () throws Error {
            ConfigModel.reload_config ();
        }

        public void change_config_value (string name,
                                         Variant value,
                                         bool write_to_file = true,
                                         string ? path = null) throws Error {
            ConfigModel.instance.change_value (name,
                                               value,
                                               write_to_file,
                                               path);
        }

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

        public void add_notification (NotifyParams param)
        throws DBusError, IOError {
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
                    cc_daemon.set_dnd (state);
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
                return false;
            });
            this.box.add (new TopAction ("Do Not Disturb", dnd_button, false));

            if (ConfigModel.instance.notification_center_height != 0) {
                this.default_height = ConfigModel.instance.notification_center_height;
            }
            this.default_width = ConfigModel.instance.notification_center_width;
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

            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.TOP, ConfigModel.instance.margin_top);
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.BOTTOM, ConfigModel.instance.margin_bottom);
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.RIGHT, ConfigModel.instance.margin_right);
            GtkLayerShell.set_margin (this, GtkLayerShell.Edge.LEFT, ConfigModel.instance.margin_left);

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
                    GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
                    this.box.set_child_packing (
                        scrolled_window, true, true, 0, Gtk.PackType.START);
                    break;
                case PositionY.TOP:
                    list_reverse = false;
                    list_align = Gtk.Align.START;
                    GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                    this.box.set_child_packing (
                        scrolled_window, true, true, 0, Gtk.PackType.END);
                    break;
            }

            if (ConfigModel.instance.fit_to_screen) {
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
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
            var adj = viewport.vadjustment;
            double val = adj.get_lower ();
            list_position = 0;
            if (reverse) {
                val = adj.get_upper ();
                list_position = list_reverse ?
                                (list_box.get_children ().length () - 1) : 0;
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
                if (w != null) list_box.remove (w);
            }

            try {
                cc_daemon.subscribe (
                    notification_count (), cc_daemon.get_dnd ());
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
            return cc_visibility;
        }

        public void close_notification (uint32 id) {
            foreach (var w in list_box.get_children ()) {
                var noti = (Notification) w;
                if (noti != null && noti.param.applied_id == id) {
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
    }
}
