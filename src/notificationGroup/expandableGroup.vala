namespace SwayNotificationCenter {
    private class ExpandableGroup : Gtk.Widget {
        const int NUM_STACKED_NOTIFICATIONS = 3;
        const int COLLAPSED_NOTIFICATION_OFFSET = 8;

        public bool is_expanded { get; private set; default = true; }

        private double animation_progress = 1.0;
        private double animation_progress_inv {
            get {
                return (1 - animation_progress);
            }
        }
        private Adw.TimedAnimation animation;
        private Adw.CallbackAnimationTarget animation_target;

        private unowned on_expand_change change_cb;

        public List<unowned Gtk.Widget> widgets = new List<unowned Gtk.Widget> ();

        public delegate void on_expand_change (bool state);

        public ExpandableGroup (uint animation_duration, on_expand_change change_cb) {
            base.set_can_focus (true);

            this.change_cb = change_cb;

            animation_target = new Adw.CallbackAnimationTarget (animation_value_cb);
            animation = new Adw.TimedAnimation (this, 1.0, 0.0,
                                                animation_duration,
                                                animation_target);
            animation.set_easing (Adw.Easing.EASE_IN_OUT_CUBIC);
            animation.done.connect (animation_done_cb);

            this.show ();

            set_expanded (false);
        }

        public void set_expanded (bool value) {
            if (is_expanded == value) {
                return;
            }
            is_expanded = value;

            animate (is_expanded ? 1 : 0);

            this.queue_resize ();

            change_cb (is_expanded);
        }

        public void add (Gtk.Widget widget) {
            widget.set_parent (this);
            widgets.append (widget);
        }

        public void remove (Gtk.Widget widget) {
            widget.unparent ();
            widgets.remove (widget);
            if (this.get_visible () && widget.get_visible ()) {
                queue_resize ();
            }
        }

        private Gtk.Allocation get_alloc (Gtk.Widget w) {
            Gtk.Allocation alloc = Gtk.Allocation ();
            Graphene.Rect bounds;
            w.compute_bounds (this, out bounds);

            alloc.width = w.get_width ();
            alloc.height = w.get_height ();
            alloc.x = (int) bounds.origin.x;
            alloc.y = (int) bounds.origin.y;
            return alloc;
        }

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        protected override void measure (Gtk.Orientation orientation, int for_size,
                                         out int minimum, out int natural,
                                         out int minimum_baseline, out int natural_baseline) {
            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;

            if (orientation == Gtk.Orientation.HORIZONTAL) {
                return;
            }

            foreach (unowned Gtk.Widget widget in widgets) {
                if (widget != null && widget.get_visible ()) {
                    int widget_minimum_height = 0;
                    int widget_natural_height = 0;
                    widget.measure (orientation, for_size,
                                    out widget_minimum_height,
                                    out widget_natural_height,
                                    null, null);

                    minimum += widget_minimum_height;
                    natural += widget_natural_height;
                }
            }

            int target_natural_height;
            int target_minimum_height;
            get_height_for_latest_notifications (for_size, out target_minimum_height,
                                                 out target_natural_height);
            // TODO: Always use natural as minimum?
            // Fixes large (tall) Notification body Pictures
            minimum = (int) Functions.lerp (minimum,
                                            target_natural_height,
                                            animation_progress_inv);
            natural = (int) Functions.lerp (natural,
                                            target_natural_height,
                                            animation_progress_inv);
        }

        protected override void size_allocate (int alloc_width, int alloc_height, int baseline) {
            base.size_allocate (alloc_width, alloc_height, baseline);

            int length = (int) widgets.length ();
            if (length == 0) {
                return;
            }

            Gtk.Allocation allocation = get_alloc (this);
            allocation.width = alloc_width;
            allocation.height = alloc_height;

            Gtk.Allocation prev_allocation = Gtk.Allocation ();
            prev_allocation.y = allocation.y;

            // The height of the most recent notification
            unowned Gtk.Widget last = widgets.last ().data;
            int target_height = 0;

            last.measure (Gtk.Orientation.VERTICAL, allocation.width, null, out target_height, null,
                          null);

            for (int i = length - 1; i >= 0; i--) {
                unowned Gtk.Widget widget = widgets.nth_data (i);
                if (widget != null && widget.get_visible ()) {
                    int height;
                    widget.measure (Gtk.Orientation.VERTICAL, allocation.width,
                                    null, out height,
                                    null, null);

                    Gtk.Allocation alloc = Gtk.Allocation ();
                    alloc.x = allocation.x;
                    alloc.y = (int) (prev_allocation.y +
                                     animation_progress * prev_allocation.height);
                    alloc.width = allocation.width;
                    alloc.height = height;
                    // Expand smaller stacked notifications to the expected height
                    // But only when the animation has finished
                    if (target_height > height && !is_expanded && animation_progress == 0) {
                        alloc.height = target_height;
                    }

                    // Add the collapsed offset to only stacked notifications.
                    // Excludes notifications index > NUM_STACKED_NOTIFICATIONS
                    if (i < length - 1 && length - 1 - i < NUM_STACKED_NOTIFICATIONS) {
                        alloc.y += (int) (animation_progress_inv * COLLAPSED_NOTIFICATION_OFFSET);
                    }

                    prev_allocation = alloc;
                    Gsk.Transform transform = new Gsk.Transform ();
                    transform = transform.translate (Graphene.Point ().init (alloc.x, alloc.y));
                    widget.allocate (alloc.width, alloc.height, baseline, transform);

                    if (get_realized ()) {
                        widget.show ();
                    }
                }
                if (get_realized ()) {
                    widget.set_child_visible (true);
                }
            }
        }

        // Draw the widget
        protected override void snapshot (Gtk.Snapshot snapshot) {
            int length = (int) widgets.length ();
            if (length == 0) {
                return;
            }

            Graphene.Rect bounds = Graphene.Rect ();
            if (!compute_bounds (this, out bounds)) {
                return;
            }
            Gtk.Allocation alloc = get_alloc (this);
            int width = alloc.width;

            unowned Gtk.Widget latest = widgets.nth_data (length - 1);
            Gtk.Allocation latest_alloc = get_alloc (latest);

            for (int i = 0; i < length; i++) {
                // Skip drawing excess notifications
                if (!is_expanded &&
                    animation_progress == 0 &&
                    i < length - NUM_STACKED_NOTIFICATIONS) {
                    continue;
                }

                unowned Gtk.Widget widget = widgets.nth_data (i);
                Gtk.Allocation widget_alloc = get_alloc (widget);

                int height_diff = latest_alloc.height - widget_alloc.height;

                snapshot.save ();

                // Move down even more if the height is larger than the latest
                // in the stack (helps with only rendering the bottom portion)
                double translate_y = height_diff * animation_progress_inv;
                snapshot.translate (Graphene.Point ().init (0, (float) translate_y));

                // Scale down lower notifications in the stack
                if (i + 1 != length) {
                    double scale = double.min (
                        animation_progress + Math.pow (0.95, length - 1 - i), 1);
                    // Moves the scaled notification to the center of X and bottom y
                    snapshot.translate (Graphene.Point ().init (
                                            (float) ((widget_alloc.width - width * scale) * 0.5),
                                            (float) (widget_alloc.height * (1 - scale))));
                    snapshot.scale ((float) scale, (float) scale);
                }

                int lerped_y = (int) Functions.lerp (-height_diff, 0, animation_progress);
                lerped_y += (int) widget_alloc.y - alloc.y;
                int lerped_height = (int) Functions.lerp (latest_alloc.height,
                                                          widget_alloc.height,
                                                          animation_progress);
                // Clip to the size of the latest notification
                // (fixes issue where a larger bottom notification would
                // be visible above)
                Graphene.Rect clip_bounds = Graphene.Rect ().init (0f,
                                                                   (float) lerped_y,
                                                                   (float) width,
                                                                   (float) lerped_height);
                snapshot.push_clip (clip_bounds);

                // TODO: Fades from the bottom at 0.5 -> top at 0.0 opacity
                // Draw patterns on the notification
                // cr.push_group ();
                // widget.draw (cr);
                // if (i + 1 != length) {
                //// Draw Fade Gradient
                // cr.save ();
                // cr.translate (0, lerped_y);
                // cr.scale (1, lerped_height * 0.5);
                // cr.set_source (fade_gradient);
                // cr.rectangle (0, 0, width, lerped_height * 0.5);
                // cr.set_operator (Cairo.Operator.DEST_OUT);
                // cr.fill ();
                // cr.restore ();
                // }
                // cr.pop_group_to_source ();
                // cr.paint ();

                // Cross-fades in the non visible stacked notifications when expanded
                if (i < length - NUM_STACKED_NOTIFICATIONS) {
                    snapshot.push_opacity (1.5 * animation_progress);
                }
                snapshot_child (widget, snapshot);

                if (i < length - NUM_STACKED_NOTIFICATIONS) {
                    snapshot.pop (); // Cross-fade
                }
                snapshot.pop (); // Clip

                snapshot.restore ();
            }
        }

        /** Gets the collapsed height (first notification + stacked) */
        private void get_height_for_latest_notifications (int for_size,
                                                          out int minimum,
                                                          out int natural) {
            minimum = 0;
            natural = 0;

            int length = (int) widgets.length ();
            if (length == 0) {
                return;
            }

            unowned GLib.List<weak Gtk.Widget> last = widgets.last ();
            if (last != null) {
                unowned Gtk.Widget last_widget = widgets.last ().data;

                last_widget.measure (Gtk.Orientation.VERTICAL, for_size,
                                     out minimum, out natural,
                                     null, null);
            }

            int offset = (length - 1).clamp (0, NUM_STACKED_NOTIFICATIONS - 1)
                * COLLAPSED_NOTIFICATION_OFFSET;

            natural += offset;
        }

        void animation_value_cb (double progress) {
            this.animation_progress = progress;

            this.queue_resize ();
        }

        void animation_done_cb () {
            this.queue_allocate ();
        }

        void animate (double to) {
            animation.set_value_from (animation_progress);
            animation.set_value_to (to);
            animation.reset ();
            animation.play ();
        }
    }
}
