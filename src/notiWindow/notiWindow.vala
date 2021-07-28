namespace SwayNotificatonCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/notiWindow/notiWindow.ui")]
    public class NotiWindow : Gtk.ApplicationWindow {

        [GtkChild]
        unowned Gtk.Box box;

        public NotiWindow () {
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
        }

        private void removeWidget (Gtk.Widget widget) {
            uint len = box.get_children ().length () - 1;
            box.remove (widget);
            if (len <= 0) box.set_visible (false);
        }

        public void add_notification (NotifyParams param, NotiDaemon notiDaemon) {
            var noti = new Notification (param, notiDaemon);
            box.pack_end (noti, false, false, 0);
            noti.show_notification ((v_noti) => {
                box.remove (v_noti);
                if (box.get_children ().length () == 0) this.hide ();
            });
            this.show_all ();
        }

        public void close_notification (uint32 id) {
            foreach (var w in box.get_children ()) {
                if (((Notification) w).param.applied_id == id) {
                    removeWidget (w);
                    break;
                }
            }
        }
    }
}
