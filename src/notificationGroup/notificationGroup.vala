namespace SwayNotificationCenter {
    public class NotificationGroup : Gtk.ListBoxRow {
        public string app_name;

        private ExpandableGroup group;
        private Gtk.Revealer revealer = new Gtk.Revealer ();

        private Gtk.GestureMultiPress gesture;
        private bool gesture_down = false;
        private bool gesture_in = false;

        public signal void on_expand_change (bool state);

        public NotificationGroup (string app_name) {
            this.app_name = app_name;
            get_style_context ().add_class ("notification-group");

            Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_UP);
            revealer.set_reveal_child (false);
            revealer.set_transition_duration (Constants.ANIMATION_DURATION);

            // Add top controls
            Gtk.Box controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            Gtk.Button collapse_button = new Gtk.Button.from_icon_name (
                "swaync-collapse", Gtk.IconSize.BUTTON);
            collapse_button.get_style_context ().add_class ("flat");
            collapse_button.get_style_context ().add_class ("circular");
            collapse_button.get_style_context ().add_class ("notification-group-collapse-button");
            collapse_button.set_relief (Gtk.ReliefStyle.NORMAL);
            collapse_button.set_halign (Gtk.Align.END);
            collapse_button.set_valign (Gtk.Align.CENTER);
            collapse_button.clicked.connect (() => {
                set_expanded (false);
                on_expand_change (false);
                group.set_sensitive (single_notification () || group.is_expanded);
            });
            Gtk.Label app_label = new Gtk.Label (app_name);
            app_label.xalign = 0;
            app_label.get_style_context ().add_class ("title-1");
            app_label.get_style_context ().add_class ("notification-group-header");

            controls_box.pack_start (app_label);
            controls_box.pack_end (collapse_button);
            revealer.add (controls_box);
            box.add (revealer);

            set_activatable (false);

            group = new ExpandableGroup (Constants.ANIMATION_DURATION, (state) => {
                revealer.set_reveal_child (state);
            });
            box.add (group);
            add (box);

            show_all ();

            /*
             * Handling of group presses
             */
            gesture = new Gtk.GestureMultiPress (this);
            gesture.set_touch_only (false);
            gesture.set_exclusive (true);
            gesture.set_button (Gdk.BUTTON_PRIMARY);
            gesture.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            gesture.pressed.connect ((_gesture, _n_press, x, y) => {
                gesture_in = true;
                gesture_down = true;
            });
            gesture.released.connect ((gesture, _n_press, _x, _y) => {
                // Emit released
                if (!gesture_down) return;
                gesture_down = false;
                if (gesture_in) {
                    bool single_noti = single_notification ();
                    if (!group.is_expanded && !single_noti) {
                        group.set_expanded (true);
                        on_expand_change (true);
                    }
                    group.set_sensitive (single_noti || group.is_expanded);
                }

                Gdk.EventSequence ? sequence = gesture.get_current_sequence ();
                if (sequence == null) {
                    gesture_in = false;
                }
            });
            gesture.update.connect ((gesture, sequence) => {
                Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
                if (sequence != gesture_single.get_current_sequence ()) return;

                Gtk.Allocation allocation;
                double x, y;

                get_allocation (out allocation);
                gesture.get_point (sequence, out x, out y);
                bool intersects = (x >= 0 && y >= 0 && x < allocation.width && y < allocation.height);
                if (gesture_in != intersects) {
                    gesture_in = intersects;
                }
            });
            gesture.cancel.connect ((gesture, sequence) => {
                if (gesture_down) {
                    gesture_down = false;
                }
            });
        }

        /// Returns if there's more than one notification
        private bool single_notification () {
            unowned Gtk.Widget ? widget = group.widgets.nth_data (1);
            return widget == null;
        }

        public void set_expanded (bool state) {
            group.set_expanded (state);
        }

        public void add_notification (Notification noti) {
            group.add (noti);
            if (!single_notification ()) {
                group.set_sensitive (false);
            }
        }

        public void remove_notification (Notification noti) {
            group.remove (noti);
            if (single_notification ()) {
                set_expanded (false);
            }
        }

        public List<weak Gtk.Widget> get_notifications () {
            return group.widgets.copy ();
        }

        public int64 get_time () {
            if (group.widgets.is_empty ()) return -1;
            return ((Notification) group.widgets.last ().data).param.time;
        }

        public uint get_num_notifications () {
            return group.widgets.length ();
        }

        public bool is_empty () {
            return group.widgets.is_empty ();
        }

        public void close_all_notifications () {
            foreach (unowned Gtk.Widget widget in group.widgets) {
                var noti = (Notification) widget;
                if (noti != null) noti.close_notification (false);
            }
        }

        public void update_time () {
            foreach (unowned Gtk.Widget widget in group.widgets) {
                var noti = (Notification) widget;
                if (noti != null) noti.set_time ();
            }
        }
    }

    private class ExpandableGroup : Gtk.Container {
        const int NUM_STACKED_NOTIFICATIONS = 3;
        const int COLLAPSED_NOTIFICATION_OFFSET = 5;

        public bool is_expanded { get; private set; default = true; }

        private double animation_progress = 1.0;
        private double animation_progress_inv {
            get {
                return (1 - animation_progress);
            }
        }
        private Animation ? animation;

        private unowned on_expand_change change_cb;

        public List<unowned Gtk.Widget> widgets = new List<unowned Gtk.Widget>();

        public delegate void on_expand_change (bool state);

        public ExpandableGroup (uint animation_duration, on_expand_change change_cb) {
            base.set_has_window (false);
            base.set_can_focus (true);
            base.set_redraw_on_allocate (false);

            this.change_cb = change_cb;
            animation = new Animation (this, animation_duration,
                                       Animation.ease_in_out_cubic,
                                       animation_value_cb,
                                       animation_done_cb);

            this.show ();

            set_expanded (false);
        }

        public void set_expanded (bool value) {
            if (is_expanded == value) return;
            is_expanded = value;

            animate (is_expanded ? 1 : 0);

            this.queue_resize ();

            change_cb (is_expanded);
        }

        public override void add (Gtk.Widget widget) {
            widget.set_parent (this);
            widgets.append (widget);
        }

        public override void remove (Gtk.Widget widget) {
            widget.unparent ();
            widgets.remove (widget);
            if (this.get_visible () && widget.get_visible ()) {
                this.queue_resize_no_redraw ();
            }
        }

        public override void forall_internal (bool include_internals, Gtk.Callback callback) {
            foreach (unowned Gtk.Widget widget in widgets) {
                callback (widget);
            }
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void size_allocate (Gtk.Allocation allocation) {
            base.size_allocate (allocation);

            int length = (int) widgets.length ();
            if (length == 0) return;

            uint border_width = get_border_width ();

            Gtk.Allocation prev_allocation = Gtk.Allocation ();
            prev_allocation.y = allocation.y;

            // The height of the most recent notification
            unowned Gtk.Widget last = widgets.last ().data;
            int target_height = 0;
            last.get_preferred_height_for_width (allocation.width,
                                                 out target_height, null);

            for (int i = length - 1; i >= 0; i--) {
                unowned Gtk.Widget widget = widgets.nth_data (i);
                if (widget != null && widget.get_visible ()) {
                    int height;
                    widget.get_preferred_height_for_width (allocation.width,
                                                           out height, null);

                    Gtk.Allocation alloc = Gtk.Allocation ();
                    alloc.x = allocation.x + (int) border_width;
                    alloc.y = (int) (prev_allocation.y +
                                     animation_progress * prev_allocation.height +
                                     border_width);
                    alloc.width = allocation.width - 2 * (int) border_width;
                    alloc.height = height;
                    // Expand smaller stacked notifications to the expected height
                    // But only when the animation has finished
                    if (target_height > height && !is_expanded && animation_progress == 0) {
                        alloc.height = target_height;
                    }
                    alloc.height -= 2 * (int) border_width;

                    // Add the collapsed offset to only stacked notifications.
                    // Excludes notifications index > NUM_STACKED_NOTIFICATIONS
                    if (i < length - 1 && length - 1 - i < NUM_STACKED_NOTIFICATIONS) {
                        alloc.y += (int) (animation_progress_inv * COLLAPSED_NOTIFICATION_OFFSET);
                    }

                    prev_allocation = alloc;
                    widget.size_allocate (alloc);

                    if (get_realized ()) {
                        widget.show ();
                    }
                }
                if (get_realized ()) {
                    widget.set_child_visible (true);
                }
            }
        }

        public override void get_preferred_height_for_width (int width,
                                                             out int minimum_height,
                                                             out int natural_height) {
            minimum_height = 0;
            natural_height = 0;

            foreach (unowned Gtk.Widget widget in widgets) {
                if (widget != null && widget.get_visible ()) {
                    int widget_minimum_height = 0;
                    int widget_natural_height = 0;
                    widget.get_preferred_height_for_width (width,
                                                           out widget_minimum_height,
                                                           out widget_natural_height);

                    minimum_height += widget_minimum_height;
                    natural_height += widget_natural_height;
                }
            }

            int target_minimum_height;
            int target_natural_height;
            get_height_for_latest_notifications (width,
                                                 out target_minimum_height,
                                                 out target_natural_height);
            minimum_height = (int) Animation.lerp (minimum_height,
                                                   target_minimum_height,
                                                   animation_progress_inv);
            natural_height = (int) Animation.lerp (natural_height,
                                                   target_natural_height,
                                                   animation_progress_inv);
        }

        public override bool draw (Cairo.Context cr) {
            int length = (int) widgets.length ();
            if (length == 0) return true;

            Gtk.Allocation alloc;
            get_allocated_size (out alloc, null);

            unowned Gtk.Widget latest = widgets.nth_data (length - 1);
            Gtk.Allocation latest_alloc;
            latest.get_allocated_size (out latest_alloc, null);

            Cairo.Pattern hover_gradient = new Cairo.Pattern.linear (0, 0, 0, 1);
            hover_gradient.add_color_stop_rgba (0, 1, 1, 1, 1);
            hover_gradient.add_color_stop_rgba (1, 1, 1, 1, 1);

            // Fades from the bottom at 0.5 -> top at 0.0 opacity
            Cairo.Pattern fade_gradient = new Cairo.Pattern.linear (0, 0, 0, 1);
            fade_gradient.add_color_stop_rgba (0, 1, 1, 1, animation_progress_inv);
            fade_gradient.add_color_stop_rgba (1, 1, 1, 1, animation_progress_inv - 0.5);
            // Cross-fades in the non visible stacked notifications when expanded
            Cairo.Pattern cross_fade_pattern =
                new Cairo.Pattern.rgba (1, 1, 1, 1.5 * animation_progress_inv);

            int width = alloc.width;

            for (int i = 0; i < length; i++) {
                // Skip drawing excess notifications
                if (!is_expanded &&
                    animation_progress == 0 &&
                    i < length - NUM_STACKED_NOTIFICATIONS) {
                    continue;
                }

                unowned Gtk.Widget widget = widgets.nth_data (i);
                int preferred_height;
                widget.get_preferred_height_for_width (width,
                                                       out preferred_height, null);
                Gtk.Allocation widget_alloc;
                widget.get_allocated_size (out widget_alloc, null);

                int height_diff = latest_alloc.height - widget_alloc.height;

                cr.save ();

                // Translate to the widgets allocated y
                double translate_y = widget_alloc.y - alloc.y;
                // Move down even more if the height is larger than the latest
                // in the stack (helps with only rendering the bottom portion)
                translate_y += height_diff * animation_progress_inv;
                cr.translate (0, translate_y);

                // Scale down lower notifications in the stack
                if (i + 1 != length) {
                    double scale = double.min (
                        animation_progress + Math.pow (0.95, length - 1 - i), 1);
                    // Moves the scaled notification to the center of X and bottom y
                    cr.translate ((widget_alloc.width - width * scale) * 0.5,
                                  widget_alloc.height * (1 - scale));
                    cr.scale (scale, scale);
                }

                int lerped_y = (int) Animation.lerp (-height_diff, 0, animation_progress);
                int lerped_height = (int) Animation.lerp (latest_alloc.height,
                                                          widget_alloc.height,
                                                          animation_progress);
                // Clip to the size of the latest notification
                // (fixes issue where a larger bottom notification would
                // be visible above)
                cr.rectangle (0, lerped_y, width, lerped_height);
                cr.clip ();

                // Draw patterns on the notification
                cr.push_group ();
                widget.draw (cr);
                if (i + 1 != length) {
                    // Draw Fade Gradient
                    cr.save ();
                    cr.translate (0, lerped_y);
                    cr.scale (1, lerped_height * 0.75);
                    cr.set_source (fade_gradient);
                    cr.rectangle (0, 0, width, lerped_height * 0.75);
                    cr.set_operator (Cairo.Operator.DEST_OUT);
                    cr.fill ();
                    cr.restore ();
                }
                // Draw notification cross-fade
                if (i < length - NUM_STACKED_NOTIFICATIONS) {
                    cr.save ();
                    cr.translate (0, lerped_y);
                    cr.scale (1, lerped_height);
                    cr.set_source (cross_fade_pattern);
                    cr.rectangle (0, 0, width, lerped_height);
                    cr.set_operator (Cairo.Operator.DEST_OUT);
                    cr.fill ();
                    cr.restore ();
                }
                cr.pop_group_to_source ();
                cr.paint ();

                cr.restore ();
            }
            return true;
        }

        /** Gets the collapsed height (first notification + stacked) */
        private void get_height_for_latest_notifications (int width,
                                                          out int minimum_height,
                                                          out int natural_height) {
            minimum_height = 0;
            natural_height = 0;

            uint length = widgets.length ();

            if (length == 0) return;

            int offset = 0;
            for (uint i = 1;
                 i < length && i < NUM_STACKED_NOTIFICATIONS;
                 i++) {
                offset += COLLAPSED_NOTIFICATION_OFFSET;
            }

            unowned Gtk.Widget last = widgets.last ().data;
            last.get_preferred_height_for_width (width,
                                                 out minimum_height,
                                                 out natural_height);

            minimum_height += offset;
            natural_height += offset;
        }

        void animation_value_cb (double progress) {
            this.animation_progress = progress;

            this.queue_resize ();
        }

        void animation_done_cb () {
            animation.dispose ();

            this.queue_allocate ();
        }

        void animate (double to) {
            animation.stop ();
            animation.start (animation_progress, to);
        }
    }
}
