namespace SwayNotificationCenter {
    [GtkTemplate (ui = "/org/erikreider/swaync/ui/notification_window.ui")]
    public class NotificationWindow : Gtk.ApplicationWindow {
        [GtkChild]
        unowned Gtk.ScrolledWindow scrolled_window;
        [GtkChild]
        unowned AnimatedList list;

        Gee.HashSet<uint32> inline_reply_notifications = new Gee.HashSet<uint32> ();
        Gee.HashMap<uint32, unowned Notification> notification_ids
            = new Gee.HashMap<uint32, unowned Notification> ();

        private static string ?monitor_name = null;

        private Ext.BackgroundEffect.Surface *bg_effect = null;
        private int[] last_blur_cards = {};
        private int last_blur_radius = -1;

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

                    update_blur_effect ();

                    // Only set ON_DEMAND after the surface has been mapped
                    Idle.add_once (() => set_keyboard_mode ());
                });
            });
            this.unmap.connect (() => {
                set_keyboard_mode ();
                destroy_blur_effect ();
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
                update_blur_effect ();
            });
        }

        ~NotificationWindow () {
            destroy_blur_effect ();
        }

        protected override void size_allocate (int w, int h, int baseline) {
            base.size_allocate (w, h, baseline);
            set_input_region ();
            update_blur_effect ();
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

        /**
         * Compositors handle the layer shell ON_DEMAND mode differently, so
         * only set the mode while mapped to reduce the chance of the users
         * input focus being stolen by an incoming notification.
         */
        private inline void set_keyboard_mode () {
            if (app.use_layer_shell) {
                if (app.has_layer_on_demand && get_mapped ()
                    && !inline_reply_notifications.is_empty) {
                    GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.ON_DEMAND);
                } else {
                    GtkLayerShell.set_keyboard_mode (this, GtkLayerShell.KeyboardMode.NONE);
                }
            }
        }

        public void update_blur_effect () {
            if (!ConfigModel.instance.background_blur
                || !app.background_effect.blur_available) {
                destroy_blur_effect ();
                return;
            }

            unowned Gdk.Surface ?gdk_surface = get_surface ();
            if (gdk_surface == null) {
                return;
            }
            unowned Wl.Surface wlsurface = Functions.get_wl_surface (gdk_surface);
            if (wlsurface == null) {
                return;
            }

            if (bg_effect == null) {
                bg_effect = app.background_effect.create_effect (wlsurface);
                if (bg_effect == null) {
                    return;
                }
            }

            double surface_x, surface_y;
            ((Gtk.Native) this).get_surface_transform (out surface_x, out surface_y);
            int offset_x = (int) surface_x;
            int offset_y = (int) surface_y;

            int visible_count = 0;
            foreach (unowned AnimatedListItem item in list.visible_children) {
                if (item != null && !item.destroying && item.child != null) {
                    visible_count++;
                }
            }

            if (visible_count == 0) {
                app.background_effect.set_blur_region (bg_effect, null);
                last_blur_cards = {};
                last_blur_radius = -1;
                queue_blur_commit ();
                return;
            }

            int[] cards = new int[visible_count * 4];
            int card_idx = 0;
            int radius = 0;
            bool got_radius = false;

            foreach (unowned AnimatedListItem item in list.visible_children) {
                if (item == null || item.destroying) {
                    continue;
                }
                unowned Notification noti = (Notification) item.child;
                if (noti == null) {
                    continue;
                }

                if (!got_radius) {
                    radius = noti.get_blur_radius ();
                    got_radius = true;
                }

                int bx, by, bw, bh;
                if (!noti.get_blur_bounds (this, out bx, out by, out bw, out bh)) {
                    continue;
                }
                int idx = card_idx * 4;
                cards[idx] = bx + offset_x;
                cards[idx + 1] = by + offset_y;
                cards[idx + 2] = bw;
                cards[idx + 3] = bh;
                card_idx++;
            }

            if (card_idx == 0) {
                app.background_effect.set_blur_region (bg_effect, null);
                last_blur_cards = {};
                last_blur_radius = -1;
                queue_blur_commit ();
                return;
            }

            if (card_idx * 4 < cards.length) {
                cards.resize (card_idx * 4);
            }

            if (cards_equal (cards, last_blur_cards) && radius == last_blur_radius) {
                return;
            }
            last_blur_cards = cards;
            last_blur_radius = radius;

            app.background_effect.set_blur_region_multi_rounded (bg_effect, cards, radius);
            unowned Gdk.Surface ?s = get_surface ();
            if (s != null) {
                s.queue_render ();
            }
        }

        private static bool cards_equal (int[] a, int[] b) {
            if (a.length != b.length) {
                return false;
            }
            for (int i = 0; i < a.length; i++) {
                if (a[i] != b[i]) {
                    return false;
                }
            }
            return true;
        }

        private void destroy_blur_effect () {
            if (bg_effect != null) {
                app.background_effect.destroy_effect (bg_effect);
                bg_effect = null;
                queue_blur_commit ();
            }
            last_blur_cards = {};
            last_blur_radius = -1;
        }

        private void queue_blur_commit () {
            unowned Gdk.Surface ?surface = get_surface ();
            if (surface != null) {
                surface.queue_render ();
            }
        }

        private void set_anchor () {
            debug ("NotificationWindow set_anchor");
            if (app.use_layer_shell) {
                GtkLayerShell.set_layer (this, ConfigModel.instance.layer.to_layer ());

                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                switch (ConfigModel.instance.positionX) {
                    case PositionX.LEFT :
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.RIGHT, false);
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.LEFT, true);
                        break;
                    case PositionX.CENTER :
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.RIGHT, false);
                        GtkLayerShell.set_anchor (
                            this, GtkLayerShell.Edge.LEFT, false);
                        break;
                        default :
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

            list.animation_add_reveal_type = AnimatedListItem.RevealAnimationType.SLIDE;
            list.animation_remove_reveal_type = AnimatedListItem.RevealAnimationType.SLIDE;
            list.animation_remove_child_type = AnimatedListItem.ChildAnimationType.NONE;
            switch (ConfigModel.instance.positionX) {
                case PositionX.LEFT:
                    list.animation_add_child_type =
                        AnimatedListItem.ChildAnimationType.SLIDE_FROM_LEFT;
                    break;
                case PositionX.CENTER:
                    list.animation_add_child_type = AnimatedListItem.ChildAnimationType.NONE;
                    break;
                default:
                case PositionX.RIGHT:
                    list.animation_add_child_type =
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

        private inline unowned Notification ?find_notification (uint32 id) {
            unowned Notification ?notification = notification_ids.get (id);
            if (notification == null || notification.param.applied_id != id) {
                return null;
            }
            unowned AnimatedListItem ?item = (AnimatedListItem ?) notification.get_parent ();
            if (item == null || item.destroying) {
                return null;
            }
            return notification;
        }

        /**
         * Hides all notifications. Only invokes the NotificationClosed signal when transient.
         * The optional callback is used to remove select notifications where each
         * iteration returns a bool. True to remove notification, false to skip.
         */
        public void remove_all_notifications (bool transition,
                                              notification_filter_func ?filter_func) {
            notification_ids.clear ();
            inline_reply_notifications.clear ();
            foreach (unowned AnimatedListItem item in list.children) {
                if (item.destroying) {
                    continue;
                }
                unowned Notification notification = (Notification) item.child;
                if (notification != null
                    && (filter_func == null || filter_func (notification))) {
                    remove_notification_internal (notification, transition);
                }
            }

            set_visible (false);
        }

        private void remove_notification_internal (Notification notification, bool transition) {
            return_if_fail (notification != null);

            NotifyParams param = notification.param;
            notification_ids.unset (param.applied_id);
            // Disable transitions when not mapped
            transition &= get_mapped ();

            if (notification.has_inline_reply) {
                inline_reply_notifications.remove (param.applied_id);
                set_keyboard_mode ();
            }

            // Remove notification and its destruction timeout
            notification.remove_noti_timeout ();
            list.remove.begin (notification, transition, (obj, res) => {
                if (list.is_empty ()) {
                    set_visible (false);
                    return;
                }
                set_input_region ();
                Idle.add_once (() => update_blur_effect ());
            });
        }

        public void add_notification (NotifyParams param) {
            var noti = new Notification.timed (param,
                                               NotificationType.FLOATING,
                                               ConfigModel.instance.timeout,
                                               ConfigModel.instance.timeout_low,
                                               ConfigModel.instance.timeout_critical);
            if (!visible) {
                destroy_blur_effect ();
                // Destroy the wl_surface to get a new "enter-monitor" signal and
                // fixes issues where keyboard shortcuts stop working after clearing
                // all notifications.
                ((Gtk.Widget) this).unrealize ();
            }

            if (noti.has_inline_reply) {
                inline_reply_notifications.add (param.applied_id);
                // Update the keyboard mode when already mapped
                if (get_mapped ()) {
                    set_keyboard_mode ();
                }
            }

            set_visible (true);

            list.append.begin (noti);
            notification_ids.set (param.applied_id, noti);
            Idle.add_once (() => update_blur_effect ());
        }

        /** Removes the notification widget with ID. Doesn't dismiss */
        public void remove_notification (uint32 id) {
            unowned Notification ?notification = find_notification (id);
            if (notification != null) {
                remove_notification_internal (notification, true);
            }
        }

        public void replace_notification (uint32 id, NotifyParams new_params) {
            unowned Notification ?notification = find_notification (id);
            if (notification != null) {
                // Replace the ID, could be changed depending on the
                // replacement method used
                notification_ids.unset (id);
                notification_ids.set (new_params.applied_id, notification);

                notification.replace_notification (new_params);
                // Position the notification in the beginning/end of the list
                // and scroll to the new item
                list.move_to_beginning (notification, true);
                return;
            }

            // Display a new notification if the old one isn't visible
            debug ("Could not find floating notification to replace: %u", id);
            add_notification (new_params);
        }

        public NotifyParams ?get_latest_notification () {
            unowned AnimatedListItem ?item = list.get_first_item ();
            if (item == null || !(item.child is Notification)) {
                warn_if_reached ();
                return null;
            }

            Notification noti = (Notification) item.child;
            return noti.param;
        }

        public void latest_notification_action (uint32 action) {
            unowned AnimatedListItem ?item = list.get_first_item ();
            if (item == null || !(item.child is Notification)) {
                warn_if_reached ();
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
