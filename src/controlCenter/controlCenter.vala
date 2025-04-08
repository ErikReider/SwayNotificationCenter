namespace SwayNotificationCenter {
    /* Only to be used by the Viewport in the Control Center */
    private class FixedViewportLayout : Gtk.LayoutManager {
        private unowned Gtk.ScrolledWindow parent;

        public FixedViewportLayout (Gtk.ScrolledWindow parent) {
            this.parent = parent;
        }

        public override void measure (Gtk.Widget widget,
                                      Gtk.Orientation orientation, int for_size,
                                      out int minimum, out int natural,
                                      out int minimum_baseline, out int natural_baseline) {
            minimum = 0;
            natural = 0;
            minimum_baseline = 0;
            natural_baseline = 0;

            if (widget == null || !widget.should_layout ()) {
                return;
            }

            unowned Gtk.Widget child = ((Gtk.Viewport) widget).child;
            if (!child.should_layout ()) {
                return;
            }

            child.measure (orientation, for_size,
                           out minimum, out natural,
                           out minimum_baseline, out natural_baseline);
        }

        public override void allocate (Gtk.Widget widget,
                                       int width, int height, int baseline) {
            if (widget == null || !widget.should_layout ()) {
                return;
            }

            unowned Gtk.Widget child = ((Gtk.Viewport) widget).child;
            if (!child.should_layout ()) {
                return;
            }

            if (ConfigModel.instance.fit_to_screen) {
                child.allocate (width, height, baseline, null);
                return;
            }

            int m_height, n_height;
            child.measure (Gtk.Orientation.VERTICAL, width,
                           out m_height, out n_height,
                           null, null);
            int m_width, n_width;
            child.measure (Gtk.Orientation.HORIZONTAL, height,
                           out m_width, out n_width,
                           null, null);

            int parent_width = parent.get_width ();
            int parent_height = parent.get_height ();

            // Limit the size to the ScrolledWindows size
            child.allocate (
                n_width.clamp ((int) Math.fmin (m_width, parent_width), parent_width),
                n_height.clamp ((int) Math.fmin (m_height, parent_height), parent_height),
                baseline, null);
        }
    }

    [GtkTemplate (ui = "/org/erikreider/swaync/ui/control_center.ui")]
    public class ControlCenter : Gtk.ApplicationWindow {
        [GtkChild]
        unowned Gtk.ScrolledWindow window;
        [GtkChild]
        unowned Gtk.Box notifications_box;
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

        IterListBoxController list_box_controller;

        [GtkChild]
        unowned IterBox box;

        unowned NotificationGroup ? expanded_group = null;
        uint scroll_timer_id = 0;

        HashTable<uint32, unowned NotificationGroup> noti_groups_id =
            new HashTable<uint32, unowned NotificationGroup> (direct_hash, direct_equal);
        /** NOTE: Only includes groups with ids with length of > 0 */
        HashTable<string, unowned NotificationGroup> noti_groups_name =
            new HashTable<string, unowned NotificationGroup> (str_hash, str_equal);

        const string STACK_NOTIFICATIONS_PAGE = "notifications-list";
        const string STACK_PLACEHOLDER_PAGE = "notifications-placeholder";

        private Gtk.GestureClick blank_window_gesture;
        private bool blank_window_down = false;
        private bool blank_window_in = false;

        private Gtk.EventControllerKey key_controller;

        private SwayncDaemon swaync_daemon;
        private NotiDaemon noti_daemon;

        private int list_position = 0;

        private bool list_reverse = false;
        private Gtk.Align list_align = Gtk.Align.START;

        private Array<Widgets.BaseWidget> widgets = new Array<Widgets.BaseWidget> ();
        private const string[] DEFAULT_WIDGETS = { "title", "dnd", "notifications" };

        public ControlCenter (SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            this.swaync_daemon = swaync_daemon;
            this.noti_daemon = noti_daemon;

            list_box_controller = new IterListBoxController (list_box);

            text_empty_label.set_text (ConfigModel.instance.text_empty);

            if (swaync_daemon.use_layer_shell) {
                if (!GtkLayerShell.is_supported ()) {
                    stderr.printf ("GTKLAYERSHELL IS NOT SUPPORTED!\n");
                    stderr.printf ("Swaync only works on Wayland!\n");
                    stderr.printf ("If running wayland session, try running:\n");
                    stderr.printf ("\tGDK_BACKEND=wayland swaync\n");
                    Process.exit (1);
                }
                GtkLayerShell.init_for_window (this);
                GtkLayerShell.set_namespace (this, "swaync-control-center");
                set_anchor ();
            }

            this.map.connect (() => {
                set_anchor ();

                unowned Gdk.Surface surface = get_surface ();
                if (!(surface is Gdk.Surface)) {
                    return;
                }

                ulong id = 0;
                id = surface.enter_monitor.connect ((monitor) => {
                    surface.disconnect (id);
                    swaync_daemon.show_blank_windows (monitor);
                });
            });
            this.unmap.connect (swaync_daemon.hide_blank_windows);

            /*
             * Handling of bank window presses (pressing outside of ControlCenter)
             */
            blank_window_gesture = new Gtk.GestureClick ();
            ((Gtk.Widget) this).add_controller (blank_window_gesture);
            blank_window_gesture.touch_only = false;
            blank_window_gesture.exclusive = true;
            blank_window_gesture.button = Gdk.BUTTON_PRIMARY;
            blank_window_gesture.propagation_phase = Gtk.PropagationPhase.BUBBLE;
            blank_window_gesture.pressed.connect ((n_press, x, y) => {
                // Calculate if the clicked coords intersect the ControlCenter
                Graphene.Point click_point = Graphene.Point ()
                    .init ((float) x, (float) y);
                Graphene.Rect ? bounds = null;
                window.compute_bounds (this, out bounds);
                blank_window_in = !(bounds != null && bounds.contains_point (click_point));
                blank_window_down = true;
            });
            blank_window_gesture.released.connect ((n_press, x, y) => {
                // Emit released
                if (!blank_window_down) return;
                blank_window_down = false;
                if (blank_window_in) {
                    try {
                        swaync_daemon.set_visibility (false);
                    } catch (Error e) {
                        stderr.printf ("ControlCenter BlankWindow Click Error: %s\n",
                                       e.message);
                    }
                }

                if (blank_window_gesture.get_current_sequence () == null) {
                    blank_window_in = false;
                }
            });
            blank_window_gesture.update.connect ((gesture, sequence) => {
                Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
                if (sequence != gesture_single.get_current_sequence ()) return;
                // Calculate if the clicked coords intersect the ControlCenter
                double x, y;
                gesture.get_point (sequence, out x, out y);
                Graphene.Point click_point = Graphene.Point ()
                    .init ((float) x, (float) y);
                Graphene.Rect ? bounds = null;
                window.compute_bounds (this, out bounds);
                if (bounds != null && bounds.contains_point (click_point)) {
                    blank_window_in = false;
                }
            });
            blank_window_gesture.cancel.connect (() => {
                blank_window_down = false;
            });

            // Only use release for closing notifications due to Escape key
            // sometimes being passed through to unfucused application
            // Ex: Firefox in a fullscreen YouTube video
            key_controller = new Gtk.EventControllerKey ();
            key_controller.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            ((Gtk.Widget) this).add_controller (key_controller);
            key_controller.key_released.connect (key_released_event_cb);
            key_controller.key_pressed.connect (key_press_event_cb);

            stack.set_visible_child_name (STACK_PLACEHOLDER_PAGE);

            add_widgets ();
        }

        // Scroll to the expanded group once said group has fully expanded
        void scroll_animate (double to) {
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

        private void key_released_event_cb (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (this.get_focus () is Gtk.Entry) {
                switch (Gdk.keyval_name (keyval)) {
                    case "Escape":
                        this.set_focus (null);
                        return;
                }
                return;
            }
            switch (Gdk.keyval_name (keyval)) {
                case "Escape":
                case "Caps_Lock":
                    this.set_visibility (false);
                    return;
            }
        }

        private bool key_press_event_cb (uint keyval, uint keycode, Gdk.ModifierType state) {
            if (this.get_focus () is Gtk.Entry) return false;
            var children = list_box_controller.get_children ();
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
                    if (group != null) {
                        int len = (int) children.length ();
                        if (len == 0) break;
                        // Add a delta so that we select the next notification
                        // due to it not being gone from the list yet due to
                        // the fade transition
                        int delta = 2;
                        if (list_reverse) {
                            if (children.first ().data != group) {
                                delta = 0;
                            }
                            list_position--;
                        } else {
                            if (list_position > 0) list_position--;
                            if (children.last ().data == group) {
                                delta = 0;
                            }
                        }
                        var noti = group.get_latest_notification ();
                        if (group.only_single_notification () && noti != null) {
                            close_notification (noti.param.applied_id, true);
                            break;
                        }
                        group.close_all_notifications ();
                        navigate_list (list_position + delta);
                        return true;
                    }
                    break;
                case "C":
                    close_all_notifications ();
                    break;
                case "D":
                    try {
                        swaync_daemon.toggle_dnd ();
                    } catch (Error e) {
                        error ("Error: %s\n", e.message);
                    }
                    break;
                case "Down":
                    if (list_position + 1 < children.length ()) {
                        ++list_position;
                    }
                    break;
                case "Up":
                    if (list_position > 0) --list_position;
                    break;
                case "Home":
                    list_position = 0;
                    break;
                case "End":
                    list_position = ((int) children.length ()) - 1;
                    if (list_position == uint.MAX) list_position = 0;
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
            navigate_list (list_position);
            // Override the builtin list navigation
            return true;
        }

        /** Adds all custom widgets. Removes previous widgets */
        public void add_widgets () {
            // Remove all widgets
            foreach (var widget in widgets.data) {
                box.remove (widget);
            }
            widgets.remove_range (0, widgets.length);

            string[] w = ConfigModel.instance.widgets.data;
            if (w.length == 0) w = DEFAULT_WIDGETS;
            bool has_notification = false;
            foreach (string key in w) {
                // Reposition the notifications_box
                // TODO: Move notifications into its own widget
                if (key == "notifications") {
                    has_notification = true;
                    unowned Gtk.Widget ? sibling = box.get_last_child ();
                    if (sibling != notifications_box) {
                        box.reorder_child_after (notifications_box, sibling);
                    }
                    continue;
                }
                // Add the widget if it is valid
                Widgets.BaseWidget ? widget = Widgets.get_widget_from_key (
                    key, swaync_daemon, noti_daemon);
                if (widget == null) continue;
                widgets.append_val (widget);
                box.append (widgets.index (widgets.length - 1));
            }
            if (!has_notification) {
                warning ("Notification widget not included in \"widgets\" config. Using default bottom position");
                unowned Gtk.Widget ? sibling = box.get_last_child ();
                if (sibling != notifications_box) {
                    box.reorder_child_after (notifications_box, sibling);
                }
            }
        }

        /** Resets the UI positions */
        private void set_anchor () {
            PositionX pos_x = ConfigModel.instance.control_center_positionX;
            if (pos_x == PositionX.NONE) pos_x = ConfigModel.instance.positionX;
            PositionY pos_y = ConfigModel.instance.control_center_positionY;
            if (pos_y == PositionY.NONE) pos_y = ConfigModel.instance.positionY;

            if (swaync_daemon.use_layer_shell) {
                // Set the exlusive zone
                int exclusive_zone = ConfigModel.instance.control_center_exclusive_zone ? 0 : 100;
                GtkLayerShell.set_exclusive_zone (this, exclusive_zone);
                // Grabs the keyboard input until closed
                bool keyboard_shortcuts = ConfigModel.instance.keyboard_shortcuts;
                var mode = keyboard_shortcuts ?
                           GtkLayerShell.KeyboardMode.EXCLUSIVE :
                           GtkLayerShell.KeyboardMode.NONE;
                GtkLayerShell.set_keyboard_mode (this, mode);

                // Set layer
                GtkLayerShell.set_layer (
                    this, ConfigModel.instance.control_center_layer.to_layer ());

                // Set whether the control center should cover the whole screen or not
                bool cover_screen = ConfigModel.instance.layer_shell_cover_screen;
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, cover_screen);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, cover_screen);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, cover_screen);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, cover_screen);
                if (!ConfigModel.instance.layer_shell_cover_screen) {
                    switch (pos_x) {
                        case PositionX.LEFT:
                            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
                            break;
                        case PositionX.CENTER:
                            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
                            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
                            break;
                        default:
                        case PositionX.RIGHT:
                            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
                            break;
                    }
                    if (ConfigModel.instance.fit_to_screen) {
                        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                        GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
                    } else {
                        switch (pos_y) {
                            default:
                            case PositionY.TOP:
                                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                                break;
                            case PositionY.CENTER:
                                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
                                break;
                            case PositionY.BOTTOM:
                                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
                                break;
                        }
                    }
                }
            }

            // Set the window margins
            window.set_margin_top (ConfigModel.instance.control_center_margin_top);
            window.set_margin_start (ConfigModel.instance.control_center_margin_left);
            window.set_margin_end (ConfigModel.instance.control_center_margin_right);
            window.set_margin_bottom (ConfigModel.instance.control_center_margin_bottom);

            // Anchor window to north/south edges as needed
            Gtk.Align align_x = Gtk.Align.END;
            switch (pos_x) {
                case PositionX.LEFT:
                    align_x = Gtk.Align.START;
                    break;
                case PositionX.CENTER:
                    align_x = Gtk.Align.CENTER;
                    break;
                default:
                case PositionX.RIGHT:
                    align_x = Gtk.Align.END;
                    break;
            }
            Gtk.Align align_y = Gtk.Align.START;
            switch (pos_y) {
                default:
                case PositionY.TOP:
                    align_y = Gtk.Align.START;
                    // Set cc widget position
                    list_reverse = false;
                    list_align = Gtk.Align.START;
                    break;
                case PositionY.CENTER:
                    align_y = Gtk.Align.CENTER;
                    // Set cc widget position
                    list_reverse = false;
                    list_align = Gtk.Align.START;
                    break;
                case PositionY.BOTTOM:
                    align_y = Gtk.Align.END;
                    // Set cc widget position
                    list_reverse = true;
                    list_align = Gtk.Align.END;
                    break;
            }
            // Fit the ControlCenter to the monitor height
            if (ConfigModel.instance.fit_to_screen) align_y = Gtk.Align.FILL;
            // Set the ControlCenter alignment
            window.set_halign (align_x);
            window.set_valign (align_y);

            list_box.set_valign (list_align);
            list_box.set_sort_func (list_box_sort_func);
            list_box.set_selection_mode (Gtk.SelectionMode.NONE);
            list_box.set_activate_on_single_click (false);

            window.set_propagate_natural_height (true);

            // Re-set the minimum size
            box.set_size_request (ConfigModel.instance.control_center_width,
                                  ConfigModel.instance.control_center_height);
            // Use a custom layout to limit the minimum size above to the size
            // of the window so that it doesn't exceed the monitors edge
            window.child.set_layout_manager (new FixedViewportLayout (window));
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

        private void scroll_to_start (bool reverse) {
            Gtk.ScrollType scroll_type = Gtk.ScrollType.START;
            if (reverse) {
                scroll_type = Gtk.ScrollType.END;
            }
            scrolled_window.scroll_child (scroll_type, false);
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
                                            get_visibility (),
                                            swaync_daemon.inhibited);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }

            if (ConfigModel.instance.hide_on_clear) {
                this.set_visibility (false);
            }
        }

        private void navigate_list (int i) {
            unowned Gtk.ListBoxRow ? widget = list_box.get_row_at_index (i);
            if (widget == null) {
                // Try getting the last widget
                if (list_reverse) {
                    widget = list_box.get_row_at_index (0);
                } else {
                    int len = ((int) list_box_controller.length) - 1;
                    widget = list_box.get_row_at_index (len);
                }
            }
            if (widget != null) {
                widget.grab_focus ();
                list_box.set_focus_child (widget);
            }
        }

        private void on_visibility_change () {
            // Updates all widgets on visibility change
            foreach (var widget in widgets.data) {
                widget.on_cc_visibility_change (visible);
            }

            if (this.visible) {
                // Focus the first notification
                list_position = (list_reverse ? (((int) list_box_controller.length) - 1) : 0)
                    .clamp (0, (int) list_box_controller.length);

                list_box.grab_focus ();
                navigate_list (list_position);
                foreach (unowned Gtk.Widget w in list_box_controller.get_children ()) {
                    var group = (NotificationGroup) w;
                    if (group != null) group.update ();
                }
                add_css_class ("open");
            } else {
                remove_css_class ("open");
            }
            swaync_daemon.subscribe_v2 (notification_count (),
                                        noti_daemon.dnd,
                                        this.visible,
                                        swaync_daemon.inhibited);
        }

        public bool toggle_visibility () {
            var cc_visibility = !this.visible;
            set_visibility (cc_visibility);
            return cc_visibility;
        }

        public void set_visibility (bool visibility) {
            if (this.visible == visibility) return;
            if (visibility) {
                // Destroy the wl_surface to get a new "enter-monitor" signal
                ((Gtk.Widget) this).unrealize ();
            }
            this.set_visible (visibility);

            on_visibility_change ();
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

                list_box_controller.remove (group);
                navigate_list (--list_position);
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
            if (group == null) {
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

                // Set the new list position when the group receives keyboard focus
                Gtk.EventControllerFocus focus_controller = new Gtk.EventControllerFocus ();
                group.add_controller (focus_controller);
                focus_controller.enter.connect (() => {
                    int i = list_box_controller.get_children ().index (group);
                    if (list_position != int.MAX && list_position != i) {
                        list_position = i;
                    }
                });

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
            scroll_to_start (list_reverse);
            try {
                swaync_daemon.subscribe_v2 (notification_count (),
                                            swaync_daemon.get_dnd (),
                                            get_visibility (),
                                            swaync_daemon.inhibited);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }

            // Keep focus on currently focused notification
            list_box.grab_focus ();
            navigate_list (++list_position);
        }

        public bool get_visibility () {
            return this.visible;
        }
    }
}
