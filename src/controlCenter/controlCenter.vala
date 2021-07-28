namespace SwayNotificatonCenter {
    [DBus (name = "org.erikreider.swaync.cc")]
    public class CcDaemon : Object {
        private ControlCenterWidget cc = null;
        private DBusInit dbusInit;

        public CcDaemon (DBusInit dbusInit) {
            this.dbusInit = dbusInit;
            cc = new ControlCenterWidget ();
        }

        public bool get_visibility () throws DBusError, IOError {
            return cc.visible;
        }

        public void toggle () throws DBusError, IOError {
            if (cc.toggle_visibility ()) {
                dbusInit.notiDaemon.set_noti_window_visibility (false);
            }
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
        unowned Gtk.Box box;

        public ControlCenterWidget () {
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
        }

        private void removeWidget (Gtk.Widget widget) {
            uint len = box.get_children ().length () - 1;
            box.remove (widget);
            if (len <= 0) {
                // Do something in the future!
            }
        }

        public bool toggle_visibility () {
            var cc_visibility = !this.visible;
            this.set_visible (cc_visibility);
            if(cc_visibility) {
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
            var noti = new Notification (param, notiDaemon, true);
            noti.set_time ();
            box.pack_end (noti, false, true, 0);
        }
    }
}
