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
            get {
                return window == null;
            }
        }

        [GtkChild]
        unowned Gtk.ScrolledWindow scrolled_window;
        [GtkChild]
        unowned Gtk.Viewport viewport;
        [GtkChild]
        unowned Gtk.Box box;

        private bool list_reverse = false;

        private double last_upper = 0;

        Gee.HashSet<uint32> inline_reply_notifications = new Gee.HashSet<uint32> ();

        private const int MAX_HEIGHT = 600;

        private NotificationWindow () {
            if (swaync_daemon.use_layer_shell) {
                if (!GtkLayerShell.is_supported ()) {
                    stderr.printf ("GTKLAYERSHELL IS NOT SUPPORTED!\n");
                    stderr.printf ("Swaync only works on Wayland!\n");
                    stderr.printf ("If running waylans session, try running:\n");
                    stderr.printf ("\tGDK_BACKEND=wayland swaync\n");
                    Process.exit (1);
                }
                GtkLayerShell.init_for_window (this);
                GtkLayerShell.set_namespace (this, "swaync-notification-window");
            }
            this.set_anchor ();

            // -1 should set it to the content size unless it exceeds max_height
            scrolled_window.set_min_content_height (-1);
            scrolled_window.set_max_content_height (MAX_HEIGHT);
            scrolled_window.set_propagate_natural_height (true);

            viewport.size_allocate.connect (size_alloc);

            this.default_width = ConfigModel.instance.notification_window_width;
        }

        private void set_anchor () {
            if (swaync_daemon.use_layer_shell) {
                GtkLayerShell.Layer layer;
                switch (ConfigModel.instance.layer) {
                    case Layer.BACKGROUND:
                        layer = GtkLayerShell.Layer.BACKGROUND;
                        break;
                    case Layer.BOTTOM:
                        layer = GtkLayerShell.Layer.BOTTOM;
                        break;
                    case Layer.TOP:
                        layer = GtkLayerShell.Layer.TOP;
                        break;
                    default:
                    case Layer.OVERLAY:
                        layer = GtkLayerShell.Layer.OVERLAY;
                        break;
                }
                GtkLayerShell.set_layer (this, layer);

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
                    default:
                    case PositionY.TOP:
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.BOTTOM, false);
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.TOP, true);
                        break;
                    case PositionY.CENTER:
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.BOTTOM, false);
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.TOP, false);
                        break;
                    case PositionY.BOTTOM:
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.TOP, false);
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.BOTTOM, true);
                        break;
                }
            }
            list_reverse = ConfigModel.instance.positionY == PositionY.BOTTOM;
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
                close ();
            } else {
                this.set_anchor ();
            }
        }

        /** Return true to remove notification, false to skip */
        public delegate bool remove_iter_func (Notification notification);

        public void close_all_notifications (remove_iter_func ? func = null) {
            inline_reply_notifications.clear ();
            if (!this.get_realized ()) return;
            foreach (var w in box.get_children ()) {
                Notification notification = (Notification) w;
                if (func == null || func (notification)) {
                    remove_notification (notification, false);
                }
            }
        }

        private void remove_notification (Notification ? noti, bool dismiss) {
            // Remove notification and its destruction timeout
            if (noti != null) {
                if (noti.has_inline_reply) {
                    inline_reply_notifications.remove (noti.param.applied_id);
                    if (inline_reply_notifications.size == 0
                        && GtkLayerShell.get_keyboard_mode (this)
                        != GtkLayerShell.KeyboardMode.NONE) {
                        GtkLayerShell.set_keyboard_mode (
                            this, GtkLayerShell.KeyboardMode.NONE);
                    }
                }
                noti.remove_noti_timeout ();
                noti.destroy ();
            }

            if (dismiss
                && (!get_realized ()
                    || !get_mapped ()
                    || !(get_child () is Gtk.Widget)
                    || box.get_children ().length () == 0)) {
                close ();
                return;
            }
        }

        public void add_notification (NotifyParams param) {
            var noti = new Notification.timed (param,
                                               swaync_daemon.noti_daemon,
                                               NotificationType.POPUP,
                                               ConfigModel.instance.timeout,
                                               ConfigModel.instance.timeout_low,
                                               ConfigModel.instance.timeout_critical);
            if (noti.has_inline_reply) {
                inline_reply_notifications.add (param.applied_id);

                if (GtkLayerShell.get_keyboard_mode (this)
                    != GtkLayerShell.KeyboardMode.ON_DEMAND) {
                    GtkLayerShell.set_keyboard_mode (
                        this, GtkLayerShell.KeyboardMode.ON_DEMAND);
                }
            }

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

        public void close_notification (uint32 id, bool dismiss) {
            foreach (var w in box.get_children ()) {
                var noti = (Notification) w;
                if (noti != null && noti.param.applied_id == id) {
                    remove_notification (noti, dismiss);
                    break;
                }
            }
        }

        public void replace_notification (uint32 id, NotifyParams new_params) {
            foreach (var w in box.get_children ()) {
                var noti = (Notification) w;
                if (noti != null && noti.param.applied_id == id) {
                    noti.replace_notification (new_params);
                    // Position the notification in the beginning of the list
                    box.reorder_child (noti, (int) box.get_children ().length ());
                    return;
                }
            }

            // Display a new notification if the old one isn't visible
            add_notification (new_params);
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
