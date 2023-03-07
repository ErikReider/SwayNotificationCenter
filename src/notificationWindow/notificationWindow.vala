namespace SwayNotificationCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/notificationWindow/notificationWindow.ui")]
    public class NotificationWindow : Gtk.ApplicationWindow {
        private static NotificationWindow ? window = null;
        /**
         * A NotificationWindow singleton due to a nasty notification
         * enter_notify_event bug where GTK still thinks that the cursor is at
         * that location after closing the last notification. The next notification
         * would sometimes automatically be hovered...
         * The only way to "solve" this is to close the window and reopen a new one.
         */
        public static NotificationWindow instance {
            get {
                if (window == null) {
                    window = new NotificationWindow ();
                } else if (!window.get_mapped () ||
                           !window.get_realized () ||
                           !(window.get_child () is Gtk.Widget)) {
                    window.destroy ();
                    window = new NotificationWindow ();
                }
                return window;
            }
        }

        public static bool is_null {
            get { return window == null; }
        }

        [GtkChild]
        unowned Gtk.ScrolledWindow scrolled_window;
        [GtkChild]
        unowned Gtk.Viewport viewport;
        [GtkChild]
        unowned Gtk.Box box;

        private bool list_reverse = false;

        private double last_upper = 0;

        private const int MAX_HEIGHT = 600;

        private NotificationWindow () {
            if (!GtkLayerShell.is_supported ()) {
                stderr.printf ("GTKLAYERSHELL IS NOT SUPPORTED!\n");
                stderr.printf ("Swaync only works on Wayland!\n");
                stderr.printf ("If running waylans session, try running:\n");
                stderr.printf ("\tGDK_BACKEND=wayland swaync\n");
                Process.exit (1);
            }
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_namespace (this, "swaync-notification-window");
            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.OVERLAY);
            this.set_anchor ();

            // -1 should set it to the content size unless it exceeds max_height
            scrolled_window.set_min_content_height (-1);
            scrolled_window.set_max_content_height (MAX_HEIGHT);
            scrolled_window.set_propagate_natural_height (true);

            viewport.size_allocate.connect (size_alloc);

            this.default_width = ConfigModel.instance.notification_window_width;
        }

        private void set_anchor () {
            switch (ConfigModel.instance.positionX) {
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
            switch (ConfigModel.instance.positionY) {
                case PositionY.BOTTOM:
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.TOP, false);
                    GtkLayerShell.set_anchor (
                        this, GtkLayerShell.Edge.BOTTOM, true);
                    list_reverse = true;
                    break;
                default:
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

        /** Return true to remove notification, false to skip */
        public delegate bool remove_iter_func(Notification notification);

        public void close_all_notifications (remove_iter_func? func = null) {
            if (!this.get_realized ()) return;
            foreach (var w in box.get_children ()) {
                Notification notification = (Notification) w;
                if (func == null || func(notification)) {
                    remove_notification (notification, false);
                }
            }
        }

        private void remove_notification (Notification ? noti, bool replaces) {
            // Remove notification and its destruction timeout
            if (noti != null) {
                noti.remove_noti_timeout ();
                noti.destroy ();
            }

            if (!replaces
                && (!get_realized ()
                    || !get_mapped ()
                    || !(get_child () is Gtk.Widget)
                    || box.get_children ().length () == 0)) {
                close ();
                return;
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
            if (!this.get_mapped () || !this.get_realized ()) {
                this.set_anchor ();
                this.show ();
            }

            // IMPORTANT: queue a resize event to force the layout to be recomputed
            noti.queue_resize ();
            scroll_to_start (list_reverse);
        }

        public void close_notification (uint32 id, bool replaces) {
            foreach (var w in box.get_children ()) {
                var noti = (Notification) w;
                if (noti != null && noti.param.applied_id == id) {
                    remove_notification (noti, replaces);
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
