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

        public void toggle () throws DBusError, IOError {
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
        unowned Gtk.Box box;

        [GtkChild]
        unowned Gtk.Label empty_label;

        public ControlCenterWidget () {
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
        }

        public uint notification_count () {
            return box.get_children ().length ();
        }

        public void close_all_notifications () {
            foreach (var w in box.get_children ()) {
                box.remove (w);
            }
        }

        private void removeWidget (Gtk.Widget widget) {
            uint len = box.get_children ().length () - 1;
            box.remove (widget);
            if (len <= 0) {
                empty_label.set_visible (true);
            }
        }

        public bool toggle_visibility () {
            var cc_visibility = !this.visible;
            this.set_visible (cc_visibility);
            if (cc_visibility) {
                foreach (var w in box.get_children ()) {
                    var noti = (Notification) w;
                    noti.set_time ();
                }
            }
            return cc_visibility;
        }

        public void close_notification (uint32 id) {
            foreach (var w in box.get_children ()) {
                if (((Notification) w).param.applied_id == id) {
                    removeWidget (w);
                    break;
                }
            }
        }

        public void add_notification (NotifyParams param, NotiDaemon notiDaemon) {
            empty_label.set_visible (false);
            var noti = new Notification (param, notiDaemon, true);
            noti.set_time ();
            box.pack_end (noti, false, true, 0);
        }
    }
}
