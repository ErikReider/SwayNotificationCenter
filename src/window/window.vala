namespace SwayNotificatonCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/window/window.ui")]
    public class NotiWindow : Gtk.ApplicationWindow {

        [GtkChild]
        unowned Gtk.Box box;

        public NotiWindow () {
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.OVERLAY);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
        }

        public void replace_notification (NotifyParams param) {
            foreach (var w in box.get_children ()) {
                if (((Notification) w).param.applied_id == param.replaces_id) {
                    box.remove (w);
                    break;
                }
            }
        }

        public void add_notification (NotifyParams param) {
            var noti = new Notification (param);
            param.printParams ();
            box.pack_end (noti, false, false, 0);
            noti.show_notification ((v_noti) => {
                box.remove (v_noti);
                if (box.get_children ().length () == 0) this.hide ();
            });
            this.show_all ();
        }
    }
}
