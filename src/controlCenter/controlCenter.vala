namespace SwayNotificationCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/controlCenter/controlCenter.ui")]
    public class ControlCenter : Gtk.ApplicationWindow {
        [GtkChild]
        unowned Gtk.Box notifications_box;
        [GtkChild]
        unowned Gtk.Label text_empty_label;
        [GtkChild]
        unowned Gtk.Stack stack;
        [GtkChild]
        unowned Gtk.ScrolledWindow scrolled_window;
        FadedViewport viewport = new FadedViewport (20);
        Gtk.ListBox list_box = new Gtk.ListBox ();

        [GtkChild]
        unowned Gtk.Box box;

        unowned NotificationGroup ? expanded_group = null;
        private double fade_animation_progress = 1.0;
        private Animation ? notification_fade_animation;
        private double scroll_animation_progress = 1.0;
        private Animation ? scroll_animation;

        HashTable<uint32, unowned NotificationGroup> noti_groups_id =
            new HashTable<uint32, unowned NotificationGroup> (direct_hash, direct_equal);
        /** NOTE: Only includes groups with ids with length of > 0 */
        HashTable<string, unowned NotificationGroup> noti_groups_name =
            new HashTable<string, unowned NotificationGroup> (str_hash, str_equal);

        const string STACK_NOTIFICATIONS_PAGE = "notifications-list";
        const string STACK_PLACEHOLDER_PAGE = "notifications-placeholder";

        private Gtk.GestureMultiPress blank_window_gesture;
        private bool blank_window_down = false;
        private bool blank_window_in = false;

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

            this.swaync_daemon.reloading_css.connect (reload_notifications_style);

            viewport.set_visible (true);
            viewport.set_vexpand (true);
            viewport.set_shadow_type (Gtk.ShadowType.NONE);
            scrolled_window.add (viewport);

            list_box.set_visible (true);
            list_box.set_valign (Gtk.Align.END);
            list_box.set_selection_mode (Gtk.SelectionMode.NONE);
            list_box.set_activate_on_single_click (false);
            list_box.get_style_context ().add_class ("control-center-list");
            viewport.add (list_box);

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
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            }

            this.map.connect (() => {
                set_anchor ();
                // Wait until the layer has attached
                ulong id = 0;
                id = notify["has-toplevel-focus"].connect (() => {
                    disconnect (id);
                    unowned Gdk.Monitor monitor = null;
                    unowned Gdk.Window ? win = get_window ();
                    if (win != null) {
                        monitor = get_display ().get_monitor_at_window (win);
                    }
                    swaync_daemon.show_blank_windows (monitor);
                });
            });
            this.unmap.connect (swaync_daemon.hide_blank_windows);

            /*
             * Handling of bank window presses (pressing outside of ControlCenter)
             */
            blank_window_gesture = new Gtk.GestureMultiPress (this);
            blank_window_gesture.set_touch_only (false);
            blank_window_gesture.set_exclusive (true);
            blank_window_gesture.set_button (Gdk.BUTTON_PRIMARY);
            blank_window_gesture.set_propagation_phase (Gtk.PropagationPhase.BUBBLE);
            blank_window_gesture.pressed.connect ((_gesture, _n_press, x, y) => {
                // Calculate if the clicked coords intersect the ControlCenter
                Gdk.Rectangle click_rectangle = Gdk.Rectangle () {
                    width = 1,
                    height = 1,
                    x = (int) x,
                    y = (int) y,
                };
                blank_window_in = !box.intersect (click_rectangle, null);
                blank_window_down = true;
            });
            blank_window_gesture.released.connect ((gesture, _n_press, _x, _y) => {
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

                Gdk.EventSequence ? sequence = gesture.get_current_sequence ();
                if (sequence == null) {
                    blank_window_in = false;
                }
            });
            blank_window_gesture.update.connect ((gesture, sequence) => {
                Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
                if (sequence != gesture_single.get_current_sequence ()) return;
                // Calculate if the clicked coords intersect the ControlCenter
                double x, y;
                gesture.get_point (sequence, out x, out y);
                Gdk.Rectangle click_rectangle = Gdk.Rectangle () {
                    width = 1,
                    height = 1,
                    x = (int) x,
                    y = (int) y,
                };
                if (box.intersect (click_rectangle, null)) {
                    blank_window_in = false;
                }
            });
            blank_window_gesture.cancel.connect ((gesture, sequence) => {
                blank_window_down = false;
            });

            // Only use release for closing notifications due to Escape key
            // sometimes being passed through to unfucused application
            // Ex: Firefox in a fullscreen YouTube video
            this.key_release_event.connect ((w, event_key) => {
                if (this.get_focus () is Gtk.Entry) {
                    switch (Gdk.keyval_name (event_key.keyval)) {
                        case "Escape":
                            this.set_focus (null);
                            return true;
                    }
                    return false;
                }
                if (event_key.type == Gdk.EventType.KEY_RELEASE) {
                    switch (Gdk.keyval_name (event_key.keyval)) {
                        case "Escape":
                        case "Caps_Lock":
                            this.set_visibility (false);
                            return true;
                    }
                }
                return true;
            });

            key_press_event.connect (key_press_event_cb);

            stack.set_visible_child_name (STACK_PLACEHOLDER_PAGE);
            // Switches the stack page depending on the amount of notifications
            list_box.add.connect (() => {
                stack.set_visible_child_name (STACK_NOTIFICATIONS_PAGE);
            });

            list_box.remove.connect ((container, _widget) => {
                if (container.get_children ().length () > 0) return;
                stack.set_visible_child_name (STACK_PLACEHOLDER_PAGE);
            });

            add_widgets ();

            notification_fade_animation = new Animation (this, Constants.ANIMATION_DURATION,
                                                         Animation.ease_in_out_cubic,
                                                         fade_animation_value_cb,
                                                         fade_animation_done_cb);
            scroll_animation = new Animation (this, Constants.ANIMATION_DURATION,
                                              Animation.ease_in_out_cubic,
                                              scroll_animation_value_cb,
                                              scroll_animation_done_cb);
            list_box.draw.connect (list_box_draw_cb);
        }

        void fade_animation_value_cb (double progress) {
            this.fade_animation_progress = progress;

            this.queue_draw ();
        }

        void fade_animation_done_cb () {}

        void fade_animate (double to) {
            notification_fade_animation.stop ();
            notification_fade_animation.start (fade_animation_progress, to);
        }

        void scroll_animation_value_cb (double progress) {
            this.scroll_animation_progress = progress;

            // Scroll to the top of the group
            if (scroll_animation_progress > 0) {
                scrolled_window.vadjustment.set_value (scroll_animation_progress);
            }
        }

        void scroll_animation_done_cb () {
            int y = expanded_group.get_relative_y (list_box);
            if (y > 0) {
                scrolled_window.vadjustment.set_value (y);
            }
        }

        void scroll_animate (double to) {
            scroll_animation.stop ();
            scroll_animation.start (scroll_animation_progress, to);
        }

        /// Fade non-expanded groups when one group is expanded
        private bool list_box_draw_cb (Cairo.Context cr) {
            Cairo.Pattern fade_gradient = new Cairo.Pattern.linear (0, 0, 0, 1);
            fade_gradient.add_color_stop_rgba (0, 1, 1, 1, 1 - fade_animation_progress - 0.5);

            foreach (unowned Gtk.Widget widget in list_box.get_children ()) {
                Gtk.Allocation alloc;
                widget.get_allocated_size (out alloc, null);

                cr.save ();
                cr.translate (0, alloc.y);

                cr.push_group ();
                widget.draw (cr);

                cr.scale (alloc.width, alloc.height);
                if (widget != expanded_group) {
                    cr.set_source (fade_gradient);
                    cr.rectangle (0, 0, alloc.width, alloc.height);
                    cr.set_operator (Cairo.Operator.DEST_OUT);
                    cr.fill ();
                }

                cr.pop_group_to_source ();
                cr.paint ();

                cr.restore ();
            }
            return true;
        }

        private bool key_press_event_cb (Gdk.EventKey event_key) {
            if (this.get_focus () is Gtk.Entry) return false;
            if (event_key.type == Gdk.EventType.KEY_PRESS) {
                var children = list_box.get_children ();
                var group = (NotificationGroup) list_box.get_focus_child ();
                switch (Gdk.keyval_name (event_key.keyval)) {
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
                            uint keyval = Gdk.keyval_from_name (
                                (i + 1).to_string ());
                            if (event_key.keyval == keyval && group != null) {
                                var noti = group.get_latest_notification ();
                                noti.click_alt_action (i);
                                break;
                            }
                        }
                        break;
                }
                navigate_list (list_position);
            }
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
                if (key == "notifications") {
                    has_notification = true;
                    uint pos = box.get_children ().length ();
                    box.reorder_child (notifications_box, (int) (pos > 0 ? --pos : 0));
                    continue;
                }
                // Add the widget if it is valid
                Widgets.BaseWidget ? widget = Widgets.get_widget_from_key (
                    key, swaync_daemon, noti_daemon);
                if (widget == null) continue;
                widgets.append_val (widget);
                box.pack_start (widgets.index (widgets.length - 1),
                                false, true, 0);
            }
            if (!has_notification) {
                warning ("Notification widget not included in \"widgets\" config. Using default bottom position");
                uint pos = box.get_children ().length ();
                box.reorder_child (notifications_box, (int) (pos > 0 ? --pos : 0));
            }
        }

        /** Resets the UI positions */
        private void set_anchor () {
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
                GtkLayerShell.Layer layer;
                switch (ConfigModel.instance.control_center_layer) {
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
            }

            // Set the box margins
            box.set_margin_top (ConfigModel.instance.control_center_margin_top);
            box.set_margin_start (ConfigModel.instance.control_center_margin_left);
            box.set_margin_end (ConfigModel.instance.control_center_margin_right);
            box.set_margin_bottom (ConfigModel.instance.control_center_margin_bottom);

            // Anchor box to north/south edges as needed
            Gtk.Align align_x = Gtk.Align.END;
            PositionX pos_x = ConfigModel.instance.control_center_positionX;
            if (pos_x == PositionX.NONE) pos_x = ConfigModel.instance.positionX;
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
            PositionY pos_y = ConfigModel.instance.control_center_positionY;
            if (pos_y == PositionY.NONE) pos_y = ConfigModel.instance.positionY;
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
            box.set_halign (align_x);
            box.set_valign (align_y);

            list_box.set_valign (list_align);
            list_box.set_sort_func (list_box_sort_func);

            // Always set the size request in all events.
            box.set_size_request (ConfigModel.instance.control_center_width,
                                  ConfigModel.instance.control_center_height);
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
            foreach (unowned Gtk.Widget widget in list_box.get_children ()) {
                if (widget is NotificationGroup) {
                    count += ((NotificationGroup) widget).get_num_notifications ();
                }
            }
            return count;
        }

        public void close_all_notifications () {
            foreach (var w in list_box.get_children ()) {
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
            unowned Gtk.Widget ? widget = list_box.get_children ().nth_data (i);
            if (widget == null) {
                // Try getting the last widget
                if (list_reverse) {
                    widget = list_box.get_children ().nth_data (0);
                } else {
                    int len = ((int) list_box.get_children ().length ()) - 1;
                    widget = list_box.get_children ().nth_data (len);
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
                list_position = list_reverse ?
                                (((int) list_box.get_children ().length ()) - 1) : 0;
                if (list_position == uint.MAX) list_position = 0;

                list_box.grab_focus ();
                navigate_list (list_position);
                foreach (var w in list_box.get_children ()) {
                    var group = (NotificationGroup) w;
                    if (group != null) group.update ();
                }
                this.get_style_context ().add_class ("open");
            }
            else {
                this.get_style_context ().remove_class ("open");
            }
            swaync_daemon.subscribe_v2 (notification_count (),
                                        noti_daemon.dnd,
                                        this.visible,
                                        swaync_daemon.inhibited);
        }

        public bool toggle_visibility () {
            var cc_visibility = !this.visible;
            if (this.visible != cc_visibility) {
                this.set_visible (cc_visibility);
                on_visibility_change ();
            }
            return cc_visibility;
        }

        public void set_visibility (bool visibility) {
            if (this.visible == visibility) return;
            this.set_visible (visibility);
            on_visibility_change ();
        }

        public void close_notification (uint32 id, bool dismiss) {
            unowned NotificationGroup group = null;
            if (!noti_groups_id.lookup_extended (id, null, out group))return;
            foreach (var w in group.get_notifications ()) {
                var noti = (Notification) w;
                if (noti != null && noti.param.applied_id == id) {
                    if (!dismiss) {
                        noti.remove_noti_timeout ();
                        noti.destroy ();
                    } else {
                        noti.close_notification (false);
                        group.remove_notification (noti);
                    }
                    noti_groups_id.remove (id);
                    break;
                }
            }
            if (group.is_empty ()) {
                if (group.name_id.length > 0) {
                    noti_groups_name.remove (group.name_id);
                }
                if (expanded_group == group) {
                    expanded_group = null;
                    fade_animate (1);
                }
                group.destroy ();
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
            noti.grab_focus.connect ((w) => {
                int i = list_box.get_children ().index (w);
                if (list_position != uint.MAX && list_position != i) {
                    list_position = i;
                }
            });
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
                        fade_animate (1);
                        foreach (unowned Gtk.Widget child in list_box.get_children ()) {
                            child.set_sensitive (true);
                        }
                        return;
                    }
                    expanded_group = group;
                    expanded_group.set_sensitive (true);
                    fade_animate (0);
                    int y = expanded_group.get_relative_y (list_box);
                    if (y > 0) {
                        scroll_animate (y);
                    }
                    foreach (unowned Gtk.Widget child in list_box.get_children ()) {
                        NotificationGroup g = (NotificationGroup) child;
                        if (g != null && g != group) {
                            g.set_expanded (false);
                            if (g.only_single_notification ()) {
                                g.set_sensitive (false);
                            }
                        }
                    }
                });
                if (param.name_id.length > 0) {
                    noti_groups_name.set (param.name_id, group);
                }
                list_box.add (group);
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

        /** Forces each notification EventBox to reload its style_context #27 */
        private void reload_notifications_style () {
            foreach (var c in list_box.get_children ()) {
                NotificationGroup group = (NotificationGroup) c;
                if (group != null) {
                    foreach (unowned var widget in group.get_notifications ()) {
                        Notification noti = (Notification) widget;
                        noti.reload_style_context ();
                    }
                }
            }
        }
    }
}
