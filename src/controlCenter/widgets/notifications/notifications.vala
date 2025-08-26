namespace SwayNotificationCenter.Widgets {
    [GtkTemplate (ui = "/org/erikreider/swaync/ui/notifications_widget.ui")]
    public class Notifications : BaseWidget {
        public override string widget_name {
            get {
                return "notifications";
            }
        }

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

        private unowned NotificationGroup ? expanded_group = null;
        private uint scroll_timer_id = 0;

        private HashTable<uint32, unowned NotificationGroup> noti_groups_id =
            new HashTable<uint32, unowned NotificationGroup> (direct_hash, direct_equal);
        /** NOTE: Only includes groups with ids with length of > 0 */
        private HashTable<string, unowned NotificationGroup> noti_groups_name =
            new HashTable<string, unowned NotificationGroup> (str_hash, str_equal);

        private bool list_reverse = false;

        // Default config values
        bool vertical_expand = true;

        public Notifications (SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base ("", swaync_daemon, noti_daemon);

            list_box_controller = new IterListBoxController (list_box);

            // TODO: Move this into notifications config!
            text_empty_label.set_text (ConfigModel.instance.text_empty);

            stack.set_visible_child_name (STACK_PLACEHOLDER_PAGE);

            list_box.set_valign (Gtk.Align.START);

            reload_config ();
        }

        public override void on_cc_visibility_change (bool value) {
            if (value) {
                focus_first_notification ();
            }
        }

        public void reload_config () {
            Json.Object ? config = get_config (this);
            if (config != null) {
                // Get vexpand
                bool found_vexpand;
                bool? vexpand = get_prop<bool> (config, "vexpand", out found_vexpand);
                if (found_vexpand) this.vertical_expand = vexpand;
            }

            set_vexpand (this.vertical_expand);
            scrolled_window.set_propagate_natural_height (!this.vertical_expand);
            stack.set_vhomogeneous (this.vertical_expand);
        }

        public uint notification_count () {
            uint count = 0;
            foreach (unowned Gtk.Widget widget in list_box_controller.get_children ()) {
                if (widget is NotificationGroup) {
                    count += ((NotificationGroup) widget).get_num_notifications ();
                }
            }
            return count;
        }

        public void close_all_notifications () {
            foreach (unowned Gtk.Widget w in list_box_controller.get_children ()) {
                NotificationGroup group = (NotificationGroup) w;
                if (group != null) group.close_all_notifications ();
            }

            try {
                swaync_daemon.subscribe_v2 (notification_count (),
                                            swaync_daemon.get_dnd (),
                                            noti_daemon.control_center.get_visibility (),
                                            swaync_daemon.inhibited);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }

            if (ConfigModel.instance.hide_on_clear) {
                noti_daemon.control_center.set_visibility (false);
            }
        }

        public void close_notification (uint32 id, bool dismiss) {
            unowned NotificationGroup group = null;
            if (!noti_groups_id.lookup_extended (id, null, out group)) {
                return;
            }
            foreach (var w in group.get_notifications ()) {
                var noti = (Notification) w;
                if (noti != null && noti.param.applied_id == id) {
                    if (dismiss) {
                        noti.close_notification (false);
                    }
                    group.remove_notification (noti);
                    noti_groups_id.remove (id);
                    break;
                }
            }

            if (group.only_single_notification ()) {
                if (expanded_group == group) {
                    expanded_group = null;
                }
            } else if (group.is_empty ()) {
                if (group.name_id.length > 0) {
                    noti_groups_name.remove (group.name_id);
                }
                if (expanded_group == group) {
                    expanded_group = null;
                }

                // Make sure to change focus to the sibling. Otherwise,
                // the ListBox focuses the first notification.
                if (list_reverse) {
                    navigate_up (group, true);
                } else {
                    navigate_down (group, true);
                }
                list_box_controller.remove (group);

                // Switches the stack page depending on the amount of notifications
                if (list_box_controller.length < 1) {
                    stack.set_visible_child_name (STACK_PLACEHOLDER_PAGE);
                }
            }
        }

        public void replace_notification (uint32 id, NotifyParams new_params) {
            unowned NotificationGroup group = null;
            if (noti_groups_id.lookup_extended (id, null, out group)) {
                foreach (var w in group.get_notifications ()) {
                    var noti = (Notification) w;
                    if (noti != null && noti.param.applied_id == id) {
                        noti_groups_id.remove (id);
                        noti_groups_id.set (new_params.applied_id, group);
                        noti.replace_notification (new_params);
                        // Position the notification in the beginning of the list
                        list_box.invalidate_sort ();
                        return;
                    }
                }
            }

            // Add a new notification if the old one isn't visible
            add_notification (new_params);
        }

        public void add_notification (NotifyParams param) {
            var noti = new Notification.regular (param,
                                                 noti_daemon,
                                                 NotificationType.CONTROL_CENTER);
            noti.set_time ();

            NotificationGroup ? group = null;
            if (param.name_id.length > 0) {
                noti_groups_name.lookup_extended (param.name_id, null, out group);
            }
            if (group == null || ConfigModel.instance.notification_grouping == false) {
                group = new NotificationGroup (param.name_id, param.display_name);
                // Collapse other groups on expand
                group.on_expand_change.connect ((expanded) => {
                    if (!expanded) {
                        foreach (unowned Gtk.Widget child in list_box_controller.get_children ()) {
                            if (child is NotificationGroup) {
                                child.remove_css_class ("not-expanded");
                            }
                        }
                        expanded_group = null;
                        return;
                    }

                    expanded_group = group;
                    float y = expanded_group.get_relative_y (list_box);
                    if (y > 0) {
                        scroll_animate (y);
                    }
                    foreach (unowned Gtk.Widget child in list_box_controller.get_children ()) {
                        NotificationGroup g = (NotificationGroup) child;
                        if (g != null && g != group) {
                            g.set_expanded (false);
                            child.add_css_class ("not-expanded");
                        }
                    }
                });
                if (param.name_id.length > 0) {
                    noti_groups_name.set (param.name_id, group);
                }

                // Switches the stack page depending on the amount of notifications
                stack.set_visible_child_name (STACK_NOTIFICATIONS_PAGE);

                list_box_controller.append (group);
            }

            // Set the group as not-expanded (reduce opacity) if there's
            // already a group that's expanded.
            if (expanded_group != null) {
                group.add_css_class ("not-expanded");
            }

            noti_groups_id.set (param.applied_id, group);

            group.add_notification (noti);
            list_box.invalidate_sort ();
            scroll_to_start ();
            try {
                swaync_daemon.subscribe_v2 (notification_count (),
                                            swaync_daemon.get_dnd (),
                                            noti_daemon.control_center.get_visibility (),
                                            swaync_daemon.inhibited);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }

            // Focus the incoming notification
            group.grab_focus ();
        }

        public void set_list_is_reversed (bool reversed) {
            list_reverse = reversed;
            list_box.set_valign (reversed ? Gtk.Align.END : Gtk.Align.START);

            list_box.set_sort_func (list_box_sort_func);
            list_box.set_selection_mode (Gtk.SelectionMode.NONE);
            list_box.set_activate_on_single_click (false);
        }

        public bool key_press_event_cb (uint keyval, uint keycode, Gdk.ModifierType state) {
            var children = list_box_controller.get_children ();
            if (!(list_box.get_focus_child () is NotificationGroup)) {
                focus_first_notification ();
            }
            var group = (NotificationGroup) list_box.get_focus_child ();
            switch (Gdk.keyval_name (keyval)) {
                case "Return":
                    if (group != null) {
                        var noti = group.get_latest_notification ();
                        if (group.only_single_notification () && noti != null) {
                            noti.click_default_action ();
                            break;
                        }
                        group.on_expand_change (group.toggle_expanded ());
                    }
                    break;
                case "Delete":
                case "BackSpace":
                    if (group != null && !children.is_empty ()) {
                        var noti = group.get_latest_notification ();
                        if (group.only_single_notification () && noti != null) {
                            close_notification (noti.param.applied_id, true);
                            break;
                        }
                        group.close_all_notifications ();
                        break;
                    }
                    break;
                case "C":
                    close_all_notifications ();
                    break;
                case "D":
                    try {
                        swaync_daemon.toggle_dnd ();
                    } catch (Error e) {
                        critical ("Error: %s\n", e.message);
                    }
                    break;
                case "Down":
                    navigate_down (group);
                    break;
                case "Up":
                    navigate_up (group);
                    break;
                case "Home":
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
            if (a_time < 0 || b_time < 0) return 0;
            // Sort the list in reverse if needed
            if (a_time == b_time) return 0;
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
            if (list_box_controller.length == 0) {
                return;
            }

            unowned Gtk.ListBoxRow ? widget = list_box.get_row_at_index (i);
            if (widget == null) {
                // Try getting the last widget
                if (list_reverse) {
                    widget = list_box.get_row_at_index (0);
                } else {
                    int len = list_box_controller.length - 1;
                    widget = list_box.get_row_at_index (len);
                }
            }
            if (widget != null) {
                widget.grab_focus ();
            } else {
                list_box.grab_focus ();
            }
        }

        private void navigate_up (NotificationGroup ? focused_group,
                                  bool fallback_other_dir = false) {
            if (list_box_controller.length == 1) {
                focus_first_notification ();
                return;
            }
            if (!(focused_group is NotificationGroup) || list_box_controller.length == 0) {
                return;
            }
            if (list_box.get_first_child () == focused_group) {
                if (fallback_other_dir) {
                    navigate_down (focused_group, false);
                }
                return;
            }

            focused_group.move_focus (Gtk.DirectionType.TAB_BACKWARD);
        }

        private void navigate_down (NotificationGroup ? focused_group,
                                    bool fallback_other_dir = false) {
            if (list_box_controller.length == 1) {
                focus_first_notification ();
                return;
            }
            if (!(focused_group is NotificationGroup) || list_box_controller.length == 0) {
                return;
            }
            if (list_box.get_last_child () == focused_group) {
                if (fallback_other_dir) {
                    navigate_up (focused_group, false);
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
            int i = (list_reverse ? 0 : list_box_controller.length - 1)
                .clamp (0, list_box_controller.length);
            navigate_list (i);
        }

        private void focus_first_notification () {
            navigate_to_first_notification ();

            foreach (unowned Gtk.Widget w in list_box_controller.get_children ()) {
                var group = (NotificationGroup) w;
                if (group != null) group.update ();
            }
        }
    }
}
