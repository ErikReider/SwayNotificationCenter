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
        private AnimationValueTarget animation_target;
        private Adw.TimedAnimation animation;

        public uint n_children { get; private set; }
        public List<unowned Gtk.Widget> visible_widgets = new List<unowned Gtk.Widget> ();

        List<Gtk.Widget> widgets = new List<Gtk.Widget> ();

        public delegate void on_expand_change (bool state);

        private unowned Gtk.Viewport viewport;

        public ExpandableGroup (Gtk.Viewport viewport,
                                uint animation_duration) {
            this.viewport = viewport;

            viewport.vadjustment.value_changed.connect (() => queue_allocate ());

            base.set_can_focus (true);

            animation_target = new AnimationValueTarget (1.0f, animation_value_cb);
            animation = new Adw.TimedAnimation (this, 1.0, 0.0,
                                                animation_duration,
                                                animation_target.get_animation_target ());
            animation.set_easing (Adw.Easing.EASE_IN_OUT_CUBIC);
            animation.done.connect (animation_done_cb);

            set_expanded (false);
        }

        public override void dispose () {
            while (!widgets.is_empty ()) {
                widgets.delete_link (widgets.nth (0));
            }
            warn_if_fail (widgets.is_empty ());
            while (!visible_widgets.is_empty ()) {
                visible_widgets.delete_link (visible_widgets.nth (0));
            }
            warn_if_fail (visible_widgets.is_empty ());

            base.dispose ();
        }

        protected override Gtk.SizeRequestMode get_request_mode () {
            foreach (unowned Gtk.Widget item in widgets) {
                if (item.get_request_mode () != Gtk.SizeRequestMode.CONSTANT_SIZE) {
                    return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
                }
            }
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        protected override void compute_expand_internal (out bool hexpand_p,
                                                         out bool vexpand_p) {
            hexpand_p = false;
            vexpand_p = false;

            foreach (unowned Gtk.Widget item in widgets) {
                hexpand_p |= item.compute_expand (Gtk.Orientation.HORIZONTAL);
                vexpand_p |= item.compute_expand (Gtk.Orientation.VERTICAL);
            }
        }

        public void set_expanded (bool value) {
            if (is_expanded == value) {
                return;
            }
            is_expanded = value;

            animate (is_expanded ? 1 : 0);

            this.queue_resize ();
        }

        public void add (Gtk.Widget widget) {
            widget.set_parent (this);
            widgets.prepend (widget);
            n_children++;
        }

        public void remove (Gtk.Widget widget) {
            bool widget_visible = widget.get_visible ();
            widget.unparent ();
            widgets.remove (widget);
            if (widget_visible) {
                queue_resize ();
            }
            n_children--;
        }

        public void remove_all () {
            while (!widgets.is_empty ()) {
                unowned List<Gtk.Widget> link = widgets.nth (0);
                if (link.data != null && link.data is Gtk.Widget) {
                    remove (link.data);
                } else {
                    widgets.delete_link (link);
                }
            }
            warn_if_fail (widgets.is_empty ());
            n_children = 0;
        }

        public delegate bool WidgetFilterDelegate (Gtk.Widget widget);

        public unowned Gtk.Widget ?get_first_widget (WidgetFilterDelegate ? filter = null) {
            for (unowned List<Gtk.Widget> ?link = widgets.first ();
                 link != null;
                 link = link.next) {
                if (link.data != null && (filter == null || filter (link.data))) {
                    return link.data;
                }
            }
            return null;
        }

        public inline bool is_empty () {
            return widgets.is_empty ();
        }

        private delegate void compute_height_iter_cb (Gtk.Widget child,
                                                      WidgetAlloc widget_alloc,
                                                      int index,
                                                      WidgetAlloc first_alloc);

        private void compute_height (int width,
                                     int height,
                                     compute_height_iter_cb iter_callback) {
            int num_vexpand_children = 0;
            WidgetHeights measured_height = WidgetHeights ();
            WidgetHeights[] heights = new WidgetHeights[n_children];
            int total_min = 0;
            int total_nat = 0;

            int i = 0;
            foreach (unowned Gtk.Widget child in widgets) {
                if (!child.should_layout ()) {
                    continue;
                }

                // Get the largest minimum height and use it for the fade distance
                int nat_width;
                // First, get the minimum width of our widget
                child.measure (Gtk.Orientation.HORIZONTAL, -1,
                               null, out nat_width, null, null);
                // Now use the natural width to retrieve the minimum and
                // natural height to display.
                int min_height, nat_height;
                child.measure (Gtk.Orientation.VERTICAL, nat_width,
                               out min_height, out nat_height, null, null);

                int min, nat;
                child.measure (Gtk.Orientation.VERTICAL, width,
                               out min, out nat, null, null);
                heights[i] = WidgetHeights () {
                    min_height = min,
                    nat_height = nat,
                };
                total_min += min;
                total_nat += nat;

                if (child.compute_expand (Gtk.Orientation.VERTICAL)) {
                    num_vexpand_children++;
                }

                i++;
            }

            bool allocate_nat = false;
            int extra_height = 0;
            if (height >= measured_height.nat_height) {
                allocate_nat = true;
                extra_height = height - measured_height.nat_height;
            } else {
                warn_if_reached ();
            }

            WidgetAlloc first_allocation = WidgetAlloc ();
            int y = 0;
            i = 0;
            foreach (unowned Gtk.Widget child in widgets) {
                WidgetHeights computed_height = heights[i];
                WidgetAlloc child_allocation = WidgetAlloc () {
                    y = 0,
                    height = computed_height.min_height,
                };
                if (allocate_nat) {
                    child_allocation.height = computed_height.nat_height;
                }

                if (child.compute_expand (Gtk.Orientation.VERTICAL)) {
                    child_allocation.height += extra_height / num_vexpand_children;
                }

                child_allocation.y = y;

                if (i == 0) {
                    first_allocation = child_allocation;
                }
                iter_callback (child, child_allocation, i, first_allocation);

                y += child_allocation.height;
                i++;
            }
        }

        private inline bool is_outside_bounds (float y, int height, float max_height) {
            return y + height < 0 || y > max_height;
        }

        protected override void size_allocate (int width, int height, int baseline) {
            base.size_allocate (width, height, baseline);

            // Recalculate which children are visible, so clear the old list
            while (!visible_widgets.is_empty ()) {
                visible_widgets.delete_link (visible_widgets.nth (0));
            }
            warn_if_fail (visible_widgets.is_empty ());


            if (n_children == 0) {
                return;
            }

            Graphene.Rect bounds;
            this.compute_bounds (viewport, out bounds);
            float max_height = viewport.get_height ();

            compute_height (width, height, (child, child_allocation, index, target_alloc) => {
                // Allocate the size and position of each item
                if (!child.should_layout ()) {
                    return;
                }

                // Expand or shrink stacked notifications to the expected height
                // (the most recent notification when collapsed)
                int child_height = (int) Adw.lerp (target_alloc.height, child_allocation.height,
                                                   animation_progress);

                //
                // Cull non-visible widgets
                //

                Graphene.Point viewport_relative_coords;
                this.compute_point (
                    viewport,
                    Graphene.Point ().init (0, child_allocation.y),
                    out viewport_relative_coords);

                bool skip_child = false;
                bool outside_bounds
                    = is_outside_bounds (viewport_relative_coords.y, child_height, max_height);
                if (animation_progress > 0 && animation_progress < 1) {
                    // Skip out of bounds notifications
                    if (index >= NUM_STACKED_NOTIFICATIONS && outside_bounds) {
                        skip_child = true;
                    }
                } else if (!is_expanded) {
                    // Skip out of bounds notifications, except for the first 3
                    if (index >= NUM_STACKED_NOTIFICATIONS) {
                        skip_child = true;
                    }
                } else if (outside_bounds) {
                    // Skip out of bounds notifications
                    skip_child = true;
                }

                if (skip_child) {
                    return;
                }

                //
                // Allocate the widget
                //

                visible_widgets.prepend (child);

                float scale = 1.0f;
                float opacity = 1.0f;
                float x = 0;
                float y = (float) Adw.lerp (0, child_allocation.y, animation_progress);

                // Add the collapsed offset to only stacked notifications.
                // Excludes notifications index > NUM_STACKED_NOTIFICATIONS
                if (index < NUM_STACKED_NOTIFICATIONS) {
                    scale = (float) double.min (
                        animation_progress + Math.pow (0.95, index), 1);
                    // Moves the scaled notification to the center of X and bottom y
                    x = (width - width * scale) * 0.5f;
                    y += child_height * (1 - scale);
                    // Apply a vertical offset to the notification
                    y += (int) Adw.lerp (COLLAPSED_NOTIFICATION_OFFSET, 0,
                                         animation_progress) * index;
                } else {
                    opacity = (float) (1.5f * animation_progress);
                }

                Gsk.Transform transform = new Gsk.Transform ()
                     .translate (Graphene.Point ().init (x, y))
                     .scale (scale, scale);
                child.allocate (width, child_height, baseline, transform);
                child.set_opacity (opacity);
            });
        }

        protected override void measure (Gtk.Orientation orientation, int for_size,
                                         out int minimum, out int natural,
                                         out int minimum_baseline, out int natural_baseline) {
            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;

            if (orientation == Gtk.Orientation.HORIZONTAL || n_children == 0) {
                return;
            }

            foreach (unowned Gtk.Widget widget in widgets) {
                if (!widget.should_layout ()) {
                    continue;
                }

                int min_height = 0;
                int nat_height = 0;
                widget.measure (orientation, for_size,
                                out min_height,
                                out nat_height,
                                null, null);
                minimum += min_height;
                natural += nat_height;
            }

            int target_nat_height;
            int target_min_height;
            get_height_for_latest_notifications (for_size, out target_min_height,
                                                 out target_nat_height);
            // TODO: Always use natural as minimum?
            // Fixes large (tall) Notification body Pictures
            minimum = (int) Functions.lerp (minimum,
                                            target_nat_height,
                                            animation_progress_inv);
            natural = (int) Functions.lerp (natural,
                                            target_nat_height,
                                            animation_progress_inv);
        }

        protected override void snapshot (Gtk.Snapshot snapshot) {
            foreach (unowned Gtk.Widget child in visible_widgets) {
                if (!child.should_layout ()) {
                    continue;
                }
                snapshot_child (child, snapshot);
            }
        }

        /** Gets the collapsed height (first notification + stacked) */
        private void get_height_for_latest_notifications (int for_size,
                                                          out int minimum,
                                                          out int natural) {
            minimum = 0;
            natural = 0;

            if (n_children == 0) {
                return;
            }

            unowned List<Gtk.Widget> first = widgets.first ();
            if (first != null) {
                unowned Gtk.Widget last_widget = first.data;

                last_widget.measure (Gtk.Orientation.VERTICAL, for_size,
                                     out minimum, out natural,
                                     null, null);
            }

            int offset = (int) (n_children - 1).clamp (0, NUM_STACKED_NOTIFICATIONS - 1)
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
