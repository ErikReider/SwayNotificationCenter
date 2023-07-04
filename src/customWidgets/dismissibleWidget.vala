namespace SwayNotificationCenter {
    public enum SwipeDirection {
        SWIPE_LEFT, SWIPE_RIGHT;
    }

    public class DismissibleWidget : Gtk.Widget, Adw.Swipeable {
        unowned Gtk.Widget child;

        // Animation
        Adw.SpringAnimation animation;
        Adw.AnimationTarget target;

        // Swipe Gesture
        Adw.SwipeTracker swipe_tracker;

        bool transition_running = false;
        bool gesture_active = false;
        double child_offset = 0;
        double swipe_progress = 0.0;

        SwipeDirection swipe_direction = SwipeDirection.SWIPE_RIGHT;

        public DismissibleWidget (Gtk.Widget child) {
            this.child = child;
            child.set_parent (this);

            swipe_tracker = new Adw.SwipeTracker (this);
            swipe_tracker.set_orientation (Gtk.Orientation.HORIZONTAL);
            swipe_tracker.set_reversed (true);
            swipe_tracker.set_allow_mouse_drag (true);

            swipe_tracker.prepare.connect (swipe_prepare_cb);
            swipe_tracker.update_swipe.connect (swipe_update_swipe_cb);
            swipe_tracker.end_swipe.connect (swipe_end_swipe_cb);

            double[] snap_dir = get_snap_points ();
            target = new Adw.CallbackAnimationTarget (animate_value_cb);
            animation = new Adw.SpringAnimation (this, snap_dir[0], snap_dir[1],
                                                 new Adw.SpringParams (1, 0.5, 500),
                                                 target);
            animation.set_clamp (true);
            animation.done.connect (animation_done_cb);
        }

        public signal void dismissed ();

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

            int child_min, child_nat;

            if (!child.visible) return;

            child.measure (orientation, for_size,
                           out child_min, out child_nat, null, null);

            minimum = int.max (minimum, child_min);
            natural = int.max (natural, child_nat);
        }

        public override void size_allocate (int width, int height, int baseline) {
            if (!child.visible) return;

            int child_width, child_height;
            int min = 0, nat = 0;

            child.measure (swipe_tracker.orientation,
                           height, out min, out nat, null, null);

            int size = width;
            if (!child.hexpand) {
                size = nat.clamp (min, width);
            }

            child_width = size;
            child_height = height;

            double x = 0;
            if (get_direction () == Gtk.TextDirection.RTL) {
                x -= ((size * swipe_progress) - (width - child_width) / 2.0)
                    + (size * child_offset * 2);
            } else {
                x -= - ((size * swipe_progress) - (width - child_width) / 2.0)
                    - (size * child_offset * 2);
            }

            Gsk.Transform transform = new Gsk.Transform ()
                .translate (Graphene.Point ().init ((float) x, 0));

            child.allocate (child_width, child_height, baseline, transform);
        }

        /*
         * Callbacks
         */

        private void animate_value_cb (double value) {
            set_position (value);
        }

        private void animation_done_cb () {
            transition_running = false;
            if (swipe_progress != 0) {
                dismissed ();
            }
        }

        private void swipe_prepare_cb (Adw.NavigationDirection direction) {
            gesture_active = true;
            if (transition_running) {
                animation.pause ();
            } else {
                transition_running = true;
            }
        }

        private void swipe_update_swipe_cb (double distance) {
            set_position (distance);
        }

        private void swipe_end_swipe_cb (double velocity, double to) {
            if (!gesture_active) return;

            animation.set_value_from (swipe_progress);
            animation.set_value_to (to);
            animation.set_initial_velocity (velocity);

            animation.play ();

            gesture_active = false;
        }

        /*
         * Methods
         */

        private void set_position (double value) {
            this.swipe_progress = value;
            queue_allocate ();
        }

        public void set_gesture_direction (SwipeDirection swipe_direction) {
            this.swipe_direction = swipe_direction;
        }

        /*
         * Swipe gesture
         */

        /** Gets the progress this will snap back to after the gesture is canceled. */
        public double get_cancel_progress () {
            return 0;
        }
        /** Gets the swipe distance of this. */
        public double get_distance () {
            return get_width ();
        }
        /** Gets the current progress of this. */
        public double get_progress () {
            if (!transition_running) return 0;
            return this.swipe_progress;
        }
        /** Gets the snap points of this. */
        public double[] get_snap_points () {
            switch (swipe_direction) {
                case SwayNotificationCenter.SwipeDirection.SWIPE_LEFT:
                    return new double[] { -1, 0 };
                default:
                case SwayNotificationCenter.SwipeDirection.SWIPE_RIGHT:
                    return new double[] { 0, 1 };
            }
        }
        /**
         * Gets the area this can start a swipe from for the given direction
         * and gesture type.
         */
        public Gdk.Rectangle get_swipe_area (Adw.NavigationDirection direction,
                                             bool is_drag) {
            Gtk.Allocation alloc;
            this.get_allocation (out alloc);
            return alloc;
        }
    }
}
