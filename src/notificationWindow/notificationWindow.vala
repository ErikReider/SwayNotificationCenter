namespace SwayNotificationCenter {
    [GtkTemplate (ui = "/org/erikreider/swaync/ui/notification_window.ui")]
    public class NotificationWindow : Gtk.ApplicationWindow {
        [GtkChild]
        unowned Gtk.ScrolledWindow scrolled_window;
        [GtkChild]
        unowned AnimatedList list;

        Gee.HashSet<uint32> inline_reply_notifications = new Gee.HashSet<uint32> ();

        private static string ?monitor_name = null;

        private const int MAX_HEIGHT = 600;

        public NotificationWindow () {
            Object (css_name: "notificationwindow");
            if (app.use_layer_shell) {
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

            this.map.connect (() => {
                set_anchor ();

                unowned Gdk.Surface surface = get_surface ();
                if (!(surface is Gdk.Surface)) {
                    warn_if_reached ();
                    return;
                }
                ulong id = 0;
                id = surface.enter_monitor.connect ((monitor) => {
                    surface.disconnect (id);
                    debug ("NotificationWindow mapped on monitor: %s",
                           Functions.monitor_to_string (monitor));
                });
            });
            this.unmap.connect (() => {
                debug ("NotificationWindow un-mapped");
            });

            // TODO: Make option
            list.use_card_animation = true;

            // set_resizable (false);
            default_width = ConfigModel.instance.notification_window_width;

            // Change output on config reload
            app.config_reload.connect ((old, config) => {
                string monitor_name = config.notification_window_preferred_output;
                if (old == null
                    || old.notification_window_preferred_output != monitor_name
                    || NotificationWindow.monitor_name != monitor_name) {
                    NotificationWindow.monitor_name = null;
                    set_anchor ();
                }
            });
        }

        protected override void size_allocate (int w, int h, int baseline) {
            base.size_allocate (w, h, baseline);

            // Set the input region to only be the size of the ScrolledWindow
            set_input_region ();
        }

        protected override void snapshot (Gtk.Snapshot snapshot) {
            // HACK: Fixes fully transparent windows not being mapped
            Gdk.RGBA color = Gdk.RGBA () {
                red = 0,
                green = 0,
                blue = 0,
                alpha = 0,
            };
            snapshot.append_color (color, Graphene.Rect.zero ());
            base.snapshot (snapshot);
        }

        private void set_anchor () {
            debug ("NotificationWindow set_anchor");
            if (app.use_layer_shell) {
                GtkLayerShell.set_layer (this, ConfigModel.instance.layer.to_layer ());

                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
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
                        scrolled_window.set_valign (Gtk.Align.START);
                        break;
                    case PositionY.CENTER:
                        scrolled_window.set_valign (Gtk.Align.CENTER);
                        break;
                    case PositionY.BOTTOM:
                        scrolled_window.set_valign (Gtk.Align.END);
                        break;
                }

                // Set the preferred monitor
                string ?monitor_name = ConfigModel.instance.notification_window_preferred_output;
                if (NotificationWindow.monitor_name != null) {
                    monitor_name = NotificationWindow.monitor_name;
                }
                set_monitor (Functions.try_get_monitor (monitor_name));
            }

            list.animation_reveal_type = AnimatedListItem.RevealAnimationType.SLIDE;
            switch (ConfigModel.instance.positionX) {
                case PositionX.LEFT:
                    list.animation_child_type = AnimatedListItem.ChildAnimationType.SLIDE_FROM_LEFT;
                    break;
                case PositionX.CENTER:
                    list.animation_child_type = AnimatedListItem.ChildAnimationType.NONE;
                    break;
                default:
                case PositionX.RIGHT:
                    list.animation_child_type =
                        AnimatedListItem.ChildAnimationType.SLIDE_FROM_RIGHT;
                    break;
            }
            switch (ConfigModel.instance.positionY) {
                default:
                case SwayNotificationCenter.PositionY.TOP:
                case SwayNotificationCenter.PositionY.CENTER:
                    list.direction = AnimatedListDirection.TOP_TO_BOTTOM;
                    break;
                case SwayNotificationCenter.PositionY.BOTTOM:
                    list.direction = AnimatedListDirection.BOTTOM_TO_TOP;
                    break;
            }

            // -1 should set it to the content size unless it exceeds max_height
            scrolled_window.set_min_content_height (-1);
            scrolled_window.set_max_content_height (
                int.max (ConfigModel.instance.notification_window_height, -1));
            scrolled_window.set_propagate_natural_height (true);

            set_input_region ();
        }

        private void set_input_region () {
            unowned Gdk.Surface ?surface = get_surface ();
            if (surface == null) {
                return;
            }

            Cairo.Region region = new Cairo.Region ();
            foreach (unowned AnimatedListItem item in list.visible_children) {
                if (item == null || !(item is Object)) {
                    critical (
                        "Could not iter over AnimatedListItem (%p) while setting input region\n",
                        item);
                    continue;
                }
                if (item.destroying) {
                    continue;
                }
                Graphene.Rect out_bounds;
                if (item.compute_bounds (this, out out_bounds)) {
                    Cairo.RectangleInt item_rect = Cairo.RectangleInt () {
                        x = (int) out_bounds.get_x (),
                        y = (int) out_bounds.get_y (),
                        width = (int) out_bounds.get_width (),
                        height = (int) out_bounds.get_height (),
                    };
                    region.union_rectangle (item_rect);
                }
            }

            // The input region should only cover each preview widget
            Graphene.Rect scrollbar_bounds;
            unowned Gtk.Widget scrollbar = scrolled_window.get_vscrollbar ();
            if (scrollbar.should_layout ()) {
                scrollbar.compute_bounds (this, out scrollbar_bounds);
                Cairo.RectangleInt rect = Cairo.RectangleInt () {
                    x = (int) scrollbar_bounds.get_x (),
                    y = (int) scrollbar_bounds.get_y (),
                    width = (int) scrollbar_bounds.get_width (),
                    height = (int) scrollbar_bounds.get_height (),
                };
                region.union_rectangle (rect);
            }

            surface.set_input_region (region);
        }

        /** Return true to remove notification, false to skip */
        public delegate bool remove_iter_func (Notification notification);

        /** Hides all notifications. Only invokes the close action when transient */
        public void hide_all_notifications (remove_iter_func ?func = null) {
            inline_reply_notifications.clear ();
            if (!this.get_realized ()) {
                return;
            }
            foreach (unowned AnimatedListItem item in list.children) {
                if (item.destroying) {
                    continue;
                }
                Notification notification = (Notification) item.child;
                if (func == null || func (notification)) {
                    remove_notification (notification, notification.param.ignore_cc (), false);
                }
            }

            set_visible (false);
        }

        private void remove_notification (Notification ?noti,
                                          bool dismiss,
                                          bool transition) {
            // Remove notification and its destruction timeout
            if (noti != null) {
                NotifyParams param = noti.param;

                if (noti.has_inline_reply) {
                    inline_reply_notifications.remove (param.applied_id);
                    if (inline_reply_notifications.size == 0
                        && app.use_layer_shell
                        && GtkLayerShell.get_keyboard_mode (this)
                        != GtkLayerShell.KeyboardMode.NONE) {
                        GtkLayerShell.set_keyboard_mode (
                            this, GtkLayerShell.KeyboardMode.NONE);
                    }
                }
                noti.remove_noti_timeout ();
                list.remove.begin (noti, transition, (obj, res) => {
                    if (dismiss && param.ignore_cc ()) {
                        noti_daemon.NotificationClosed (param.applied_id,
                                                        ClosedReasons.DISMISSED);
                    }
                    if (list.is_empty ()) {
                        set_visible (false);
                        return;
                    }
                    set_input_region ();
                });
            }
        }

        public void add_notification (NotifyParams param) {
            var noti = new Notification.timed (param,
                                               NotificationType.POPUP,
                                               ConfigModel.instance.timeout,
                                               ConfigModel.instance.timeout_low,
                                               ConfigModel.instance.timeout_critical);
            if (noti.has_inline_reply) {
                inline_reply_notifications.add (param.applied_id);

                if (app.use_layer_shell &&
                    GtkLayerShell.get_keyboard_mode (this)
                    != GtkLayerShell.KeyboardMode.ON_DEMAND
                    && app.has_layer_on_demand) {
                    GtkLayerShell.set_keyboard_mode (
                        this, GtkLayerShell.KeyboardMode.ON_DEMAND);
                }
            }

            set_visible (true);

            list.append.begin (noti);
        }

        public void close_notification (uint32 id, bool dismiss) {
            foreach (unowned AnimatedListItem item in list.children) {
                if (item.destroying) {
                    continue;
                }
                var noti = (Notification) item.child;
                if (noti != null && noti.param.applied_id == id) {
                    remove_notification (noti, dismiss, true);
                    break;
                }
            }
        }

        public void replace_notification (uint32 id, NotifyParams new_params) {
            foreach (unowned AnimatedListItem item in list.children) {
                if (item.destroying) {
                    continue;
                }
                var noti = (Notification) item.child;
                if (noti != null && noti.param.applied_id == id) {
                    noti.replace_notification (new_params);
                    // Position the notification in the beginning/end of the list
                    // and scroll to the new item
                    list.move_to_beginning (noti, true);
                    return;
                }
            }

            // Display a new notification if the old one isn't visible
            debug ("Could not find floating notification to replace: %u", id);
            add_notification (new_params);
        }

        public NotifyParams ?get_latest_notification () {
            unowned AnimatedListItem ?item = list.get_first_item ();
            if (item == null || !(item.child is Notification)) {
                return null;
            }

            Notification noti = (Notification) item.child;
            return noti.param;
        }

        public void latest_notification_action (uint32 action) {
            unowned AnimatedListItem ?item = list.get_first_item ();
            if (item == null || !(item.child is Notification)) {
                return;
            }

            Notification noti = (Notification) item.child;
            noti.click_alt_action (action);
        }

        public void set_monitor (Gdk.Monitor ?monitor) {
            debug ("Setting monitor for Floating Notifications: %s",
                   Functions.monitor_to_string (monitor) ?? "Monitor Picked by Compositor");
            NotificationWindow.monitor_name = monitor == null ? null : monitor.connector;
            GtkLayerShell.set_monitor (this, monitor);

            set_input_region ();
        }
    }
}
