namespace SwayNotificationCenter {
    public class NotiWindow {
        private NotificationWindow notis = new NotificationWindow ();

        private unowned NotificationWindow notificationWindow {
            get {
                if (!notis.get_realized () || notis.closed) {
                    notis = new NotificationWindow ();
                }
                return notis;
            }
        }

        public void change_visibility (bool value) {
            notificationWindow.change_visibility (value);
        }

        public void close_all_notifications () {
            notificationWindow.close_all_notifications ();
        }

        public void add_notification (NotifyParams param,
                                      NotiDaemon noti_daemon) {
            notificationWindow.add_notification (param, noti_daemon);
        }

        public void close_notification (uint32 id) {
            notificationWindow.close_notification (id);
        }

        public uint32 ? get_latest_notification () {
            if (!notis.get_realized () || notis.closed) return null;
            return notificationWindow.get_latest_notification ();
        }
    }

    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/notiWindow/notiWindow.ui")]
    private class NotificationWindow : Gtk.ApplicationWindow {

        [GtkChild]
        unowned Gtk.Viewport viewport;
        [GtkChild]
        unowned Gtk.Box box;

        private bool list_reverse = false;

        private double last_upper = 0;

        public bool closed = false;

        public NotificationWindow () {
            if (!GtkLayerShell.is_supported ()) {
                stderr.printf ("GTKLAYERSHELL IS NOT SUPPORTED!\n");
                stderr.printf ("Swaync only works on Wayland!\n");
                stderr.printf ("If running waylans session, try running:\n");
                stderr.printf ("\tGDK_BACKEND=wayland swaync\n");
                Process.exit (1);
            }
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.OVERLAY);
            this.set_anchor ();
            viewport.size_allocate.connect (size_alloc);

            this.default_width = ConfigModel.instance.notification_window_width;
        }

        private void set_anchor () {
            switch (ConfigModel.instance.position_x) {
                case PositionX.LEFT:
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.RIGHT, false);
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.LEFT, true);
                    break;
                case PositionX.CENTER:
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.RIGHT, false);
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.LEFT, false);
                    break;
                default:
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.LEFT, false);
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.RIGHT, true);
                    break;
            }
            switch (ConfigModel.instance.position_y) {
                case PositionY.BOTTOM:
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.TOP, false);
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.BOTTOM, true);
                    list_reverse = true;
                    break;
                case PositionY.TOP:
                    list_reverse = false;
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.BOTTOM, false);
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.TOP, true);
                    break;
            }
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
            var val = (reverse ? adj.get_upper () : adj.get_lower ());
            adj.set_value (val);
        }

        public void change_visibility (bool value) {
            if (!value) {
                close_all_notifications ();
            } else {
                this.set_anchor ();
            }
        }

        public void close_all_notifications () {
            if (!this.get_realized ()) return;
            foreach (var w in box.get_children ()) {
                remove_notification ((Notification) w);
            }
        }

        private void remove_notification (Notification noti) {
            // Remove notification and its destruction timeout
            if (noti != null) {
                noti.remove_noti_timeout ();
                noti.destroy ();
            }

            if (!this.get_realized ()) return;
            if (box.get_children ().length () == 0) {
                this.closed = true;
                this.close ();
            }
        }

        public void add_notification (NotifyParams param,
                                      NotiDaemon noti_daemon) {
            var noti = new Notification.timed (param,
                                               noti_daemon,
                                               ConfigModel.instance.timeout,
                                               ConfigModel.instance.timeout_low,
                                               ConfigModel.instance.timeout_critical);

            if (list_reverse) {
                box.pack_start (noti);
            } else {
                box.pack_end (noti);
            }
            this.grab_focus ();
            this.show ();
            scroll_to_start (list_reverse);
        }

        public void close_notification (uint32 id) {
            foreach (var w in box.get_children ()) {
                var noti = (Notification) w;
                if (noti != null && noti.param.applied_id == id) {
                    remove_notification (noti);
                    break;
                }
            }
        }

        public uint32 ? get_latest_notification () {
            List<weak Gtk.Widget> children = box.get_children ();
            if (children.is_empty ()) return null;

            Gtk.Widget ? child = null;
            if (list_reverse) {
                child = children.last ().data;
            } else {
                child = children.first ().data;
            }

            if (child == null || !(child is Notification)) return null;
            Notification noti = (Notification) child;
            return noti.param.applied_id;
        }
    }
}
