namespace SwayNotificationCenter {
    public class NotificationWindow : Gtk.Window {
        private const int MAX_HEIGHT = 600;

        Gtk.ScrolledWindow scrolled_window;
        Gtk.Viewport viewport;
        IterBox box = new IterBox (Gtk.Orientation.VERTICAL, 0);

        private bool list_reverse = false;

        private double last_upper = 0;

        Gee.HashSet<uint32> inline_reply_notifications = new Gee.HashSet<uint32> ();

        private unowned NotiDaemon noti_daemon;
        private unowned SwayncDaemon swaync_daemon;

        public NotificationWindow (SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            this.noti_daemon = noti_daemon;
            this.swaync_daemon = swaync_daemon;

            // Build widget
            add_css_class ("floating-notifications");

            // set_child (scrolled_window = new CustomScrolledWindow.propagate (MAX_HEIGHT));
            // scrolled_window.set_scrollable (viewport = new Gtk.Viewport (null, null));
            set_child (scrolled_window = new Gtk.ScrolledWindow ());
            scrolled_window.set_child (viewport = new Gtk.Viewport (null, null));
            scrolled_window.set_min_content_height (-1);
            scrolled_window.set_max_content_height (MAX_HEIGHT);
            scrolled_window.set_propagate_natural_height (true);
            scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            viewport.set_child (box);

            if (swaync_daemon.use_layer_shell) {
                if (!GtkLayerShell.is_supported ()) {
                    stderr.printf ("GTKLAYERSHELL IS NOT SUPPORTED!\n");
                    stderr.printf ("Swaync only works on Wayland!\n");
                    stderr.printf ("If running wayland session, try running:\n");
                    stderr.printf ("\tGDK_BACKEND=wayland swaync\n");
                    Process.exit (1);
                }
                GtkLayerShell.init_for_window (this);
                GtkLayerShell.set_namespace (this, "swaync-notification-window");
            }
            this.set_anchor ();

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
                        scrolled_window.set_valign (Gtk.Align.START);
                        break;
                    case PositionY.CENTER:
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.BOTTOM, false);
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.TOP, false);
                        scrolled_window.set_valign (Gtk.Align.CENTER);
                        break;
                    case PositionY.BOTTOM:
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.TOP, false);
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.BOTTOM, true);
                        scrolled_window.set_valign (Gtk.Align.END);
                        break;
                }
            }
            list_reverse = ConfigModel.instance.positionY == PositionY.BOTTOM;
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void measure (Gtk.Orientation orientation, int for_size,
                                      out int minimum_size, out int natural_size,
                                      out int minimum_baseline, out int natural_baseline) {
            minimum_size = 1;
            natural_size = 1;
            minimum_baseline = -1;
            natural_baseline = -1;

            int child_min = 0;
            int child_nat = 0;
            int child_min_baseline = -1;
            int child_nat_baseline = -1;
            scrolled_window.measure (orientation, for_size,
                                     out child_min, out child_nat,
                                     out child_min_baseline, out child_nat_baseline);

            minimum_size = int.min (MAX_HEIGHT, int.max (minimum_size, child_min));
            natural_size = int.min (MAX_HEIGHT, int.max (natural_size, child_nat));

            if (child_min_baseline > -1) {
                minimum_baseline = int.max (minimum_baseline, child_min_baseline);
            }
            if (child_nat_baseline > -1) {
                natural_baseline = int.max (natural_baseline, child_nat_baseline);
            }

            // Input region not being resized unless default_height is set to -1
            // Layer shell issue?
            default_height = -1;
        }

        public override void size_allocate (int width, int height, int baseline) {
            // Scroll to the top/latest notification
            var adj = viewport.vadjustment;
            double upper = adj.get_upper ();
            if (last_upper < upper) {
                scroll_to_start (list_reverse);
            }
            last_upper = upper;

            base.size_allocate (width, height, baseline);
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
                this.show ();
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

        private void remove_notification (Notification ? noti, bool replaces) {
            // Remove notification and its destruction timeout
            if (noti != null) {
                if (noti.has_inline_reply) {
                    inline_reply_notifications.remove (noti.param.applied_id);
                    if (swaync_daemon.use_layer_shell
                        && inline_reply_notifications.size == 0
                        && GtkLayerShell.get_keyboard_mode (this)
                        != GtkLayerShell.KeyboardMode.NONE) {
                        GtkLayerShell.set_keyboard_mode (
                            this, GtkLayerShell.KeyboardMode.NONE);
                    }
                }
                noti.remove_noti_timeout ();
                box.remove (noti);
            }

            if (!replaces && box.length == 0) {
                hide ();
                // Reset to 0 due to Sway asserting that the size is a positive value
                default_height = 0;
            }
        }

        public void add_notification (NotifyParams param,
                                      NotiDaemon noti_daemon) {
            Notification notification = new Notification ();
            notification.construct_notification (param, noti_daemon, NotificationType.POPUP);
            if (notification.has_inline_reply) {
                inline_reply_notifications.add (param.applied_id);

                if (swaync_daemon.use_layer_shell
                    && GtkLayerShell.get_keyboard_mode (this)
                    != GtkLayerShell.KeyboardMode.ON_DEMAND) {
                    GtkLayerShell.set_keyboard_mode (
                        this, GtkLayerShell.KeyboardMode.ON_DEMAND);
                }
            }

            if (list_reverse) {
                box.append (notification);
            } else {
                box.prepend (notification);
            }

            change_visibility (true);

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
            Gtk.Widget ? child = null;
            if (list_reverse) {
                child = box.get_last_child ();
            } else {
                child = box.get_first_child ();
            }

            if (child == null || !(child is Notification)) return null;
            Notification noti = (Notification) child;
            return noti.param.applied_id;
        }
    }
}
