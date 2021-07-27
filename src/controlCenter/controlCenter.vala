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

        public void update () throws DBusError, IOError {
            cc.update (this.dbusInit.notifications);
        }
    }

    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/controlCenter/controlCenter.ui")]
    private class ControlCenterWidget : Gtk.ApplicationWindow {

        [GtkChild]
        unowned Gtk.Box box;

        public ControlCenterWidget () {
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.OVERLAY);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
        }

        public bool toggle_visibility () {
            var vis = !this.visible;
            this.set_visible (vis);
            return vis;
        }

        public void update (List<NotifyParams ? > notifications) {
            foreach (var child in box.get_children ()) {
                box.remove (child);
            }
            var notis = notifications.copy ();
            notis.reverse ();
            foreach (var param in notis) {
                var noti = new Notification (param, true);
                box.add (noti);
            }
        }
    }
}
