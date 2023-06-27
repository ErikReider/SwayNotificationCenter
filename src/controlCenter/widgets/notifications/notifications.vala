namespace SwayNotificationCenter.Widgets {
    public class NotiListItemModel : Object {
        public unowned Notification notification;
        public unowned NotiDaemon noti_daemon;
        public NotifyParams param;
        public NotificationType notification_type;
    }

    public class Notifications : Gtk.Widget {
        public uint notification_count {
            get {
                return list_model.n_items;
            }
        }

        // CustomScrolledWindow scrolled_window = new CustomScrolledWindow ();
        Gtk.ScrolledWindow scrolled_window;
        Gtk.Stack stack;

        // Gtk.ListBox notification_list = new Gtk.ListBox ();
        Gtk.ListView notification_list;
        private uint list_position = 0;
        private double last_upper = 0;
        private bool list_reverse = false;
        private Gtk.Align list_align = Gtk.Align.START;

        private List<unowned NotiListItemModel> visible_models = new List<unowned NotiListItemModel> ();
        private ListStore list_model = new ListStore (typeof (NotiListItemModel));

        NotificationType notification_type { get; private set; }

        const string STACK_PLACEHOLDER_PAGE = "notifications-placeholder";
        const string STACK_NOTIFICATIONS_PAGE = "notifications-list";

        public Notifications (NotificationType notification_type) {
            this.notification_type = notification_type;

            this.vexpand = true;
            this.valign = Gtk.Align.FILL;

            stack = new Gtk.Stack () {
                vhomogeneous = false,
                transition_type = Gtk.StackTransitionType.CROSSFADE,
            };
            stack.set_parent (this);

            // Notifications
            stack.add_named (scrolled_window = new Gtk.ScrolledWindow () {
                hexpand = true,
                valign = Gtk.Align.FILL,
                hscrollbar_policy = Gtk.PolicyType.NEVER,
            }, STACK_NOTIFICATIONS_PAGE);
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect (item_factory_setup_cb);
            factory.bind.connect (item_factory_bind_cb);
            factory.unbind.connect (item_factory_unbind_cb);
            // TODO: Use single selection for keyboard navigation?
            var selection_model = new Gtk.NoSelection (list_model);
            notification_list = new Gtk.ListView (selection_model, factory) {
                single_click_activate = false,
            };
            notification_list.add_css_class ("control-center-list");
            scrolled_window.set_child (notification_list);

            // Placeholder
            Gtk.CenterBox placeholder = new Gtk.CenterBox () {
                valign = Gtk.Align.CENTER,
            };
            stack.add_named (placeholder, STACK_PLACEHOLDER_PAGE);
            Gtk.Box placeholder_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
                css_classes = { "control-center-list-placeholder" }
            };
            placeholder.set_center_widget (placeholder_box);
            placeholder_box.append (new Gtk.Image () {
                icon_name = "notifications-placeholder-symbolic",
                pixel_size = 96
            });
            placeholder_box.append (new Gtk.Label ("No Notifications"));

            // Switches the stack page depending on the
            list_model.items_changed.connect (list_model_items_changed_cb);

            map.connect_after (() => {
                print ("MAP!\n");
                // WORKS THE SECOND TIME...
                foreach (unowned NotiListItemModel model in visible_models) {
                    print ("MODEL: %s\n", model.param.summary);
                    model.notification.queue_resize ();
                }
                notification_list.queue_resize ();
            });
        }

        /*
         * Callbacks
         */

        /**
         * Emitted to set up permanent things on the listitem. This usually
         * means constructing the widgets used in the row and adding them to
         * the listitem.
         */
        private void item_factory_setup_cb (Gtk.SignalListItemFactory factory,
                                            Gtk.ListItem item) {
            Notification noti = new Notification ();
            item.set_child (noti);
            // noti.queue_resize ();
        }

        /**
         * Emitted to bind the item passed via [ property@Gtk.ListItem:item]
         * to the widgets that have been created in step 1 or to add
         * item-specific widgets. Signals are connected to listen to
         * changes - both to changes in the item to update the widgets or to
         * changes in the widgets to update the item. After this signal has been
         * called, the listitem may be shown in a list widget.
         */
        private void item_factory_bind_cb (Gtk.SignalListItemFactory factory,
                                           Gtk.ListItem item) {
            unowned Notification noti = (Notification) item.get_child ();
            unowned NotiListItemModel model = (NotiListItemModel) item.get_item ();
            model.notification = noti;
            noti.construct_notification (model.param,
                                         model.noti_daemon,
                                         model.notification_type);
            noti.set_time ();
            // TODO: Fix some large notifications being clipped for some reason...

            visible_models.append (model);
        }

        private void item_factory_unbind_cb (Gtk.SignalListItemFactory factory,
                                             Gtk.ListItem item) {
            unowned NotiListItemModel model = (NotiListItemModel) item.get_item ();
            visible_models.remove (model);
        }

        private void list_model_items_changed_cb () {
            switch (notification_count) {
                case 0:
                    stack.set_visible_child_name (STACK_PLACEHOLDER_PAGE);
                    break;
                default:
                    stack.set_visible_child_name (STACK_NOTIFICATIONS_PAGE);
                    break;
            }
        }

        /*
         * Private methods
         */

        private int model_sort_func (Object w1, Object w2) {
            var a = (NotiListItemModel) w1;
            var b = (NotiListItemModel) w2;
            if (a == null || b == null) return 0;
            // Sort the list in reverse if needed
            if (a.param.time == b.param.time) return 0;
            int val = list_reverse ? 1 : -1;
            return a.param.time > b.param.time ? val : val * -1;
        }

        private void scroll_to_start (bool reverse) {
            Gtk.ScrollType scroll_type = Gtk.ScrollType.START;
            if (reverse) {
                scroll_type = Gtk.ScrollType.END;
            }
            scrolled_window.scroll_child (scroll_type, false);
        }

        /*
         * Overrides
         */

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void measure (Gtk.Orientation orientation, int for_size,
                                      out int minimum, out int natural,
                                      out int minimum_baseline, out int natural_baseline) {
            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;

            for (Gtk.Widget child = get_first_child ();
                 child != null;
                 child = child.get_next_sibling ()) {
                int child_min = 0;
                int child_nat = 0;
                int child_min_baseline = -1;
                int child_nat_baseline = -1;

                child.measure (orientation, for_size,
                               out child_min, out child_nat,
                               out child_min_baseline, out child_nat_baseline);

                minimum = int.max (minimum, child_min);
                natural = int.max (natural, child_nat);

                if (child_min_baseline > -1) {
                    minimum_baseline = int.max (minimum_baseline, child_min_baseline);
                }
                if (child_nat_baseline > -1) {
                    natural_baseline = int.max (natural_baseline, child_nat_baseline);
                }
            }
        }

        public override void size_allocate (int width, int height, int baseline) {
            for (Gtk.Widget child = get_first_child ();
                 child != null;
                 child = child.get_next_sibling ()) {
                if (!child.should_layout ()) continue;

                child.allocate (width, height, baseline, null);
            }

            // Scroll to the top/latest notification
            var adj = notification_list.vadjustment;
            double upper = adj.get_upper ();
            if (last_upper < upper) {
                scroll_to_start (list_reverse);
            }
            last_upper = upper;
        }

        /*
         * Public methods
         */

        public void set_list_orientation () {
            PositionY pos_y = PositionY.NONE;
            if (notification_type == NotificationType.CONTROL_CENTER)
                pos_y = ConfigModel.instance.control_center_positionY;
            if (pos_y == PositionY.NONE) pos_y = ConfigModel.instance.positionY;
            switch (pos_y) {
                default:
                case PositionY.TOP:
                    list_reverse = false;
                    list_align = Gtk.Align.START;
                    break;
                case PositionY.CENTER:
                    list_reverse = false;
                    list_align = Gtk.Align.START;
                    break;
                case PositionY.BOTTOM:
                    list_reverse = true;
                    list_align = Gtk.Align.END;
                    break;
            }

            notification_list.set_valign (list_align);
        }

        public void close_all_notifications () {
            while (list_model.n_items > 0) {
                NotiListItemModel model = (NotiListItemModel) list_model.get_object (0);
                if (model != null && model.notification != null) {
                    model.notification.close_notification (false);
                }
                list_model.remove (0);
            }
        }

        public void close_notification (uint32 id, bool replaces = false) {
            for (uint i = 0; i < notification_count; i++) {
                NotiListItemModel model = (NotiListItemModel) list_model.get_object (i);
                if (model != null && model.param.applied_id == id) {
                    unowned Notification noti = model.notification;
                    if (replaces) {
                        noti.remove_noti_timeout ();
                    } else {
                        noti.close_notification (false);
                    }
                    list_model.remove (i);
                    break;
                }
            }
        }

        public void add_notification (NotifyParams param,
                                      NotiDaemon noti_daemon) {
            NotiListItemModel model = new NotiListItemModel () {
                noti_daemon = noti_daemon,
                param = param,
                notification_type = NotificationType.CONTROL_CENTER,
            };

            // TODO: Make sure that this works
            // noti.focus_event.enter.connect ((w) => {
            // uint i = 0;
            // if (list_model.find (noti, out i) &&
            // list_position != uint.MAX && list_position != i) {
            // list_position = i;
            // }
            // });
            // noti.set_time ();

            list_model.insert_sorted (model, model_sort_func);
            scroll_to_start (list_reverse);

            // Keep focus on currently focused notification
            grab_list_focus ();

            if (notification_type == NotificationType.CONTROL_CENTER) {
                navigate_list (++list_position);
            }
        }

        public void navigate_list (uint i) {
            var model = (NotiListItemModel) list_model.get_object (i);
            if (model != null && model.notification != null) {
                notification_list.set_focus_child (model.notification);
                model.notification.grab_focus ();
            }
        }

        /** Focus the first notification */
        public void navigate_to_start () {
            list_position = list_reverse ? (list_model.n_items - 1) : 0;
            if (list_position == uint.MAX) list_position = 0;

            grab_list_focus ();
            navigate_list (list_position);
        }

        public void grab_list_focus () {
            notification_list.grab_focus ();
        }

        // TODO: MAke sure that this works automatically in ::bind
        public void refresh_notifications_time () {
            for (uint i = 0; i < notification_count; i++) {
                NotiListItemModel model = (NotiListItemModel) list_model.get_object (i);
                if (model != null && model.notification != null) {
                    model.notification.set_time ();
                }
            }
        }

        public unowned NotiListItemModel ? get_latest_notification () {
            Object ? object = null;
            if (list_reverse) {
                // last
                object = list_model.get_item (uint.min (0, list_model.get_n_items () - 1));
            } else {
                // first
                object = list_model.get_item (0);
            }

            if (object == null || !(object is NotiListItemModel)) return null;
            return (NotiListItemModel) object;
        }
    }
}
