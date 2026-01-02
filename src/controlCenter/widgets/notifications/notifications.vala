namespace SwayNotificationCenter.Widgets {
    [GtkTemplate (ui = "/org/erikreider/swaync/ui/notifications_widget.ui")]
    public class Notifications : BaseWidget {
        public override string widget_name {
            get {
                return "notifications";
            }
        }

        public uint n_notifications { get; private set; default = 0; }
        public uint n_groups { get; private set; default = 0; }

        const string STACK_NOTIFICATIONS_PAGE = "notifications-list";
        const string STACK_PLACEHOLDER_PAGE = "notifications-placeholder";

        [GtkChild]
        unowned Gtk.Label text_empty_label;
        [GtkChild]
        unowned Gtk.Stack stack;
        [GtkChild]
        unowned Gtk.ScrolledWindow scrolled_window;
        [GtkChild]
        unowned Gtk.Viewport viewport;
        [GtkChild]
        unowned Gtk.ListBox list_box;

        private IterListBoxController list_box_controller;

        internal unowned NotificationGroup ?expanded_group {
            internal get; private set; default = null;
        }
        private uint scroll_timer_id = 0;

        private Gee.HashMap<uint32, unowned NotificationGroup> noti_groups_id =
            new Gee.HashMap<uint32, unowned NotificationGroup> ();
        /** NOTE: Only includes groups with ids with length of > 0 */
        private Gee.HashMap<string, unowned NotificationGroup> noti_groups_name =
            new Gee.HashMap<string, unowned NotificationGroup> ();

        private bool list_reverse = false;

        // Default config values
        bool vertical_expand = true;

        public Notifications () {
            base ("");

            list_box_controller = new IterListBoxController (list_box);

            notify["expanded-group"].connect (expanded_changed);

            // TODO: Move this into notifications config!
            text_empty_label.set_text (ConfigModel.instance.text_empty);

            stack.set_visible_child_name (STACK_PLACEHOLDER_PAGE);

            list_box.set_valign (Gtk.Align.START);

            reload_config ();
        }

        // Add/remove the "not-expanded" CSS class to each group
        private void expanded_changed () {
            bool is_expanded = expanded_group != null;
            foreach (unowned Gtk.Widget child in list_box_controller.get_children ()) {
                if (child is NotificationGroup) {
                    unowned NotificationGroup group = (NotificationGroup) child;
                    if (is_expanded && group != expanded_group) {
                        group.set_expanded (false);
                        group.add_css_class ("not-expanded");
                    } else {
                        group.remove_css_class ("not-expanded");
                    }
                }
            }
        }

        public override void on_cc_visibility_change (bool value) {
            if (value) {
                navigate_to_first_notification ();

                foreach (unowned Gtk.Widget w in list_box_controller.get_children ()) {
                    var group = (NotificationGroup) w;
                    if (group != null) {
                        group.update ();
                    }
                }
            }
        }

        public void reload_config () {
            Json.Object ?config = get_config (this);
            if (config != null) {
                // Get vexpand
                bool found_vexpand;
                bool ?vexpand = get_prop<bool> (config, "vexpand", out found_vexpand);
                if (found_vexpand) {
                    this.vertical_expand = vexpand;
                }
            }

            set_vexpand (this.vertical_expand);
            scrolled_window.set_propagate_natural_height (!this.vertical_expand);
            stack.set_vhomogeneous (this.vertical_expand);
        }

        public inline bool is_empty () {
            return n_notifications == 0;
        }

        public void request_dismiss_all_notifications () {
            noti_daemon.request_dismiss_all_notifications (ClosedReasons.DISMISSED);
        }

        private void prepare_group_removal (NotificationGroup group) {
            if (group.name_id.length > 0) {
                noti_groups_name.unset (group.name_id);
            }
            if (expanded_group == group) {
                expanded_group = null;
            }

            // Only change the group focus if the dismissed group is focused
            unowned NotificationGroup ?focused_group =
                (NotificationGroup) list_box.get_focus_child ();
            if (focused_group == null || focused_group == group) {
                // Make sure to change focus to the sibling. Otherwise,
                // the ListBox focuses the first notification.
                if (list_reverse) {
                    navigate_up (true);
                } else {
                    navigate_down (true);
                }
            }
        }

        private void commit_group_removal (NotificationGroup group) {
            list_box_controller.remove (group);

            // Switches the stack page depending on the amount of notifications
            if (list_box_controller.length < 1) {
                n_notifications = 0;
                n_groups = 0;
                stack.set_visible_child_name (STACK_PLACEHOLDER_PAGE);
            }
        }

        public void remove_all_notifications (bool animate) {
            noti_groups_id.clear ();
            n_notifications = 0;
            n_groups = 0;
            foreach (unowned Gtk.Widget w in list_box_controller.get_children ()) {
                NotificationGroup group = (NotificationGroup) w;
                if (group != null) {
                    prepare_group_removal (group);
                    group.remove_all_notifications.begin (true, (obj, result) => {
                        if (group.remove_all_notifications.end (result)) {
                            commit_group_removal (group);
                        }
                    });
                }
            }

            if (ConfigModel.instance.hide_on_clear) {
                control_center.set_visibility (false);
            }
        }

        public void remove_group (string group_name_id) {
            NotificationGroup ?group = noti_groups_name.get (group_name_id);
            if (group == null) {
                return;
            }
            remove_group_internal (group);
        }

        private void remove_group_internal (NotificationGroup group) {
            foreach (uint32 id in group.notification_ids.keys) {
                if (noti_groups_id.unset (id)) {
                    n_notifications--;
                }
            }
            n_groups--;

            prepare_group_removal (group);
            group.remove_all_notifications.begin (true, (obj, result) => {
                if (group.remove_all_notifications.end (result)) {
                    commit_group_removal (group);
                }
            });
        }

        /** Removes the notification widget with ID. Doesn't dismiss */
        public void remove_notification (uint32 id) {
            NotificationGroup ?group = noti_groups_id.get (id);
            if (group == null) {
                return;
            }
            if (group.state == NotificationGroupState.MANY) {
                noti_groups_id.unset (id);
                n_notifications--;
                group.remove_notification.begin (id, (obj, result) => {
                    // Continue the removal logic even if the async result failed
                    // due to the groups state still being updated
                    if (group.state == NotificationGroupState.EMPTY) {
                        n_groups--;
                        prepare_group_removal (group);
                        commit_group_removal (group);
                    }
                });
            } else {
                remove_group_internal (group);
            }
        }

        public void replace_notification (uint32 id, NotifyParams new_params) {
            unowned NotificationGroup ?group = noti_groups_id.get (id);
            if (group != null) {
                noti_groups_id.unset (id);
                if (group.replace_notification (id, new_params)) {
                    // Replace the ID, could be changed depending on the
                    // replacement method used
                    noti_groups_id.set (new_params.applied_id, group);
                    // Position the notification in the beginning of the list
                    list_box.invalidate_sort ();
                    return;
                }
            }

            // Add a new notification if the old one isn't visible
            add_notification (new_params);
        }

        public void add_notification (NotifyParams param) {
            var noti = new Notification.regular (param, NotificationType.CONTROL_CENTER);
            noti.set_time ();

            NotificationGroup ?group = null;
            if (param.name_id.length > 0) {
                group = noti_groups_name.get (param.name_id);
            }
            if (group == null || group.dismissed
                || ConfigModel.instance.notification_grouping == false) {
                group = new NotificationGroup (param.name_id, param.display_name, viewport);
                // Collapse other groups on expand
                group.on_expand_change.connect ((expanded) => {
                    if (!expanded) {
                        expanded_group = null;
                        return;
                    }

                    expanded_group = group;
                    float y = expanded_group.get_relative_y (list_box);
                    if (y > 0) {
                        scroll_animate (y);
                    }
                });
                if (param.name_id.length > 0) {
                    noti_groups_name.set (param.name_id, group);
                }

                stack.set_visible_child_name (STACK_NOTIFICATIONS_PAGE);

                list_box_controller.append (group);
                n_groups++;
            }

            // Set the group as not-expanded (reduce opacity) if there's
            // already a group that's expanded.
            if (expanded_group != null) {
                group.add_css_class ("not-expanded");
            }

            group.add_notification (noti);
            noti_groups_id.set (param.applied_id, group);
            n_notifications++;

            list_box.invalidate_sort ();

            scroll_to_start ();
        }

        public void set_list_is_reversed (bool reversed) {
            list_reverse = reversed;
            list_box.set_valign (reversed ? Gtk.Align.END : Gtk.Align.START);

            list_box.set_sort_func (list_box_sort_func);
            list_box.set_selection_mode (Gtk.SelectionMode.NONE);
            list_box.set_activate_on_single_click (false);
        }

        public bool key_press_event_cb (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (!(list_box.get_focus_child () is NotificationGroup)) {
                navigate_to_first_notification ();
            }
            unowned NotificationGroup group = (NotificationGroup) list_box.get_focus_child ();
            switch (Gdk.keyval_name (keyval)) {
                case "Return" :
                    if (group != null) {
                        var noti = group.get_latest_notification ();
                        if (group.state == NotificationGroupState.SINLGE && noti != null) {
                            noti.click_default_action ();
                            break;
                        }
                        group.on_expand_change (group.toggle_expanded ());
                    }
                    break;
                case "Delete" :
                case "BackSpace" :
                    if (group != null && n_groups > 0) {
                        unowned Notification ?noti = group.get_latest_notification ();
                        if (group.state == NotificationGroupState.SINLGE && noti != null) {
                            noti.request_dismiss_notification (ClosedReasons.DISMISSED, false);
                            break;
                        }
                        group.request_dismiss_all_notifications ();
                        break;
                    }
                    break;
                case "C" :
                    request_dismiss_all_notifications ();
                    break;
                case "D" :
                    try {
                        swaync_daemon.toggle_dnd ();
                    } catch (Error e) {
                        critical ("Error: %s\n", e.message);
                    }
                    break;
                case "Down" :
                    navigate_down (false, group);
                    break;
                case "Up" :
                    navigate_up (false, group);
                    break;
                case "Home" :
                    navigate_to_first_notification ();
                    break;
                case "End":
                    navigate_to_last_notification ();
                    break;
                default:
                    // Pressing 1-9 to activate a notification action
                    for (int i = 0; i < 9; i++) {
                        uint num_keyval = Gdk.keyval_from_name (
                            (i + 1).to_string ());
                        if (keyval == num_keyval && group != null) {
                            var noti = group.get_latest_notification ();
                            noti.click_alt_action (i);
                            break;
                        }
                    }
                    break;
            }
            // Override the builtin list navigation
            return true;
        }

        /**
         * Returns < 0 if row1 should be before row2, 0 if they are equal
         * and > 0 otherwise
         */
        private int list_box_sort_func (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
            int val = list_reverse ? 1 : -1;

            var a_group = (NotificationGroup) row1;
            var b_group = (NotificationGroup) row2;

            // Check urgency before time
            var a_urgency = a_group.get_is_urgent ();
            var b_urgency = b_group.get_is_urgent ();
            if (a_urgency != b_urgency) {
                return a_urgency ? val : val * -1;
            }

            // Check time
            var a_time = a_group.get_time ();
            var b_time = b_group.get_time ();
            if (a_time < 0 || b_time < 0) {
                return 0;
            }
            // Sort the list in reverse if needed
            if (a_time == b_time) {
                return 0;
            }
            return a_time > b_time ? val : val * -1;
        }

        // Scroll to the expanded group once said group has fully expanded
        private void scroll_animate (double to) {
            if (scroll_timer_id > 0) {
                Source.remove (scroll_timer_id);
                scroll_timer_id = 0;
            }
            scroll_timer_id = Timeout.add_once (Constants.ANIMATION_DURATION, () => {
                scroll_timer_id = 0;
                if (expanded_group == null) {
                    return;
                }
                float y = expanded_group.get_relative_y (list_box);
                if (y > 0) {
                    viewport.scroll_to (expanded_group, null);
                }
            });
        }

        private void scroll_to_start () {
            Gtk.ScrollType scroll_type = Gtk.ScrollType.START;
            if (list_reverse) {
                scroll_type = Gtk.ScrollType.END;
            }
            scrolled_window.scroll_child (scroll_type, false);
        }

        private void navigate_list (int i) {
            if (n_groups == 0) {
                return;
            }

            unowned NotificationGroup ?group = (NotificationGroup) list_box.get_row_at_index (i);
            if (group == null) {
                // Try getting the last widget
                if (list_reverse) {
                    group = (NotificationGroup) list_box.get_row_at_index (0);
                } else {
                    int len = int.max (0, list_box_controller.length - 1);
                    group = (NotificationGroup) list_box.get_row_at_index (len);
                }
            }

            if (group != null) {
                if (group.dismissed) {
                    // Try to find the next non-dismissed group
                    bool list_reverse = this.list_reverse;
                    unowned NotificationGroup ?sibling = group;
                    for (size_t j = 0; j < n_groups; j++) {
                        sibling = (NotificationGroup)
                            (list_reverse ? sibling.get_prev_sibling () :
                             sibling.get_next_sibling ());
                        if (sibling == null) {
                            debug ("Could not find a non-dismissed group to focus");
                            list_box.grab_focus ();
                            return;
                        }
                        if (!sibling.dismissed) {
                            group = sibling;
                            break;
                        }
                    }
                }
                group.grab_focus ();
            } else {
                list_box.grab_focus ();
            }
        }

        private void navigate_up (bool fallback_other_dir,
                                  NotificationGroup ?focused_group = null) {
            if (focused_group == null) {
                focused_group = (NotificationGroup) list_box.get_focus_child ();
            }

            if (n_groups == 0) {
                return;
            } else if (!(focused_group is NotificationGroup) || n_groups == 1) {
                navigate_to_first_notification ();
                return;
            }

            if (list_box.get_first_child () == focused_group) {
                if (fallback_other_dir) {
                    navigate_down (false, focused_group);
                }
                return;
            }
            focused_group.move_focus (Gtk.DirectionType.TAB_BACKWARD);
        }

        private void navigate_down (bool fallback_other_dir,
                                    NotificationGroup ?focused_group = null) {
            if (focused_group == null) {
                focused_group = (NotificationGroup) list_box.get_focus_child ();
            }

            if (n_groups == 0) {
                return;
            } else if (!(focused_group is NotificationGroup) || n_groups == 1) {
                navigate_to_first_notification ();
                return;
            }

            if (list_box.get_last_child () == focused_group) {
                if (fallback_other_dir) {
                    navigate_up (false, focused_group);
                }
                return;
            }
            focused_group.move_focus (Gtk.DirectionType.TAB_FORWARD);
        }

        private void navigate_to_first_notification () {
            int i = (list_reverse ? list_box_controller.length - 1 : 0)
                 .clamp (0, list_box_controller.length);
            navigate_list (i);
        }

        private void navigate_to_last_notification () {
            int i = (!list_reverse ? list_box_controller.length - 1 : 0)
                 .clamp (0, list_box_controller.length);
            navigate_list (i);
        }
    }
}
