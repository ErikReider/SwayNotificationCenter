namespace SwayNotificatonCenter {
    [DBus (name = "org.erikreider.swaync.cc")]
    public class CcDaemon : Object {
        private ControlCenterWidget cc = null;
        private DBusInit dbusInit;

        public CcDaemon (DBusInit dbusInit) {
            this.dbusInit = dbusInit;
            cc = new ControlCenterWidget ();

            dbusInit.notiDaemon.on_dnd_toggle.connect ((dnd) => {
                try {
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

        public bool get_dnd () throws DBusError, IOError {
            return dbusInit.notiDaemon.get_dnd ();
        }

        public void add_notification (NotifyParams param) throws DBusError, IOError {
            cc.add_notification (param, dbusInit.notiDaemon);
            subscribe (notification_count (), dbusInit.notiDaemon.get_dnd ());
        }

        public void close_notification (uint32 id) throws DBusError, IOError {
            cc.close_notification (id);
            subscribe (notification_count (), dbusInit.notiDaemon.get_dnd ());
        }
    }

    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/controlCenter/controlCenter.ui")]
    private class ControlCenterWidget : Gtk.ApplicationWindow {

        [GtkChild]
        unowned Gtk.ListBox list_box;

        private uint list_position = 0;

        public ControlCenterWidget () {
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
            // Grabs the keyboard input until closed
            GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.ON_DEMAND);

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
                            if (list_box.get_children ().last ().data == noti) {
                                if (list_position > 0) --list_position;
                            }
                            list_box.remove (noti);
                        }
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
                        if (list_position < 0) list_position = 0;
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

            list_box.set_sort_func ((w1, w2) => {
                var a = (Notification) w1;
                var b = (Notification) w2;
                if (a != null && b != null) {
                    return a.param._time > b.param._time ? -1 : 1;
                }
                return 0;
            });
        }

        public uint notification_count () {
            return list_box.get_children ().length ();
        }

        public void close_all_notifications () {
            foreach (var w in list_box.get_children ()) {
                list_box.remove (w);
            }
        }

        private void navigate_list (uint i) {
            var widget = list_box.get_children ().nth_data (i);
            if (widget != null) {
                list_box.set_focus_child (widget);
                widget.grab_focus ();
            }
        }

        public bool toggle_visibility () {
            var cc_visibility = !this.visible;
            this.set_visible (cc_visibility);

            if (cc_visibility) {
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
        }

        public void add_notification (NotifyParams param, NotiDaemon notiDaemon) {
            var noti = new Notification (param, notiDaemon, true);
            noti.grab_focus.connect ((w) => {
                uint i = list_box.get_children ().index (w);
                if (list_position != uint.MAX && list_position != i) {
                    list_position = i;
                }
            });
            noti.set_time ();
            list_box.add (noti);
        }
    }
}
