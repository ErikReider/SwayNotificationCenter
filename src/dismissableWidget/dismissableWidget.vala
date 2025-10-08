public enum SwipeDirection {
    SWIPE_LEFT, SWIPE_RIGHT;
}

public class DismissibleWidget : Gtk.Widget, Adw.Swipeable {
    protected unowned Gtk.Widget _child = null;
    public unowned Gtk.Widget child {
        get {
            return _child;
        }
        set {
            _child = value;
            if (_child != null) {
                _child.unparent ();
                _child.set_parent (this);
            }
        }
    }

    public Gtk.Orientation orientation {
        get;
        private set;
        default = Gtk.Orientation.HORIZONTAL;
    }

    // Animation
    Adw.SpringAnimation animation;

    // Swipe Gesture
    Adw.SwipeTracker swipe_tracker;

    bool transition_running = false;
    bool gesture_active = false;
    private double _swipe_progress = 0.0;
    public double swipe_progress {
        get {
            return _swipe_progress;
        }
        set {
            _swipe_progress = value;
            queue_allocate ();
        }
    }

    SwipeDirection swipe_direction = SwipeDirection.SWIPE_RIGHT;

    construct {
        swipe_tracker = new Adw.SwipeTracker (this);
        swipe_tracker.set_orientation (orientation);
        swipe_tracker.set_reversed (true);
        swipe_tracker.set_upper_overshoot (true);
        swipe_tracker.set_lower_overshoot (true);
        swipe_tracker.set_allow_long_swipes (true);
        swipe_tracker.set_enabled (true);
        swipe_tracker.set_allow_mouse_drag (true);

        swipe_tracker.prepare.connect (swipe_prepare_cb);
        swipe_tracker.update_swipe.connect (swipe_update_swipe_cb);
        swipe_tracker.end_swipe.connect (swipe_end_swipe_cb);

        double[] snap_dir = get_snap_points ();
        Adw.PropertyAnimationTarget target = new Adw.PropertyAnimationTarget (this, "swipe-progress");
        animation = new Adw.SpringAnimation (this, snap_dir[0], snap_dir[1],
                                             new Adw.SpringParams (1, 0.5, 500),
                                             target);
        animation.set_clamp (true);
        animation.done.connect (animation_done_cb);
    }

    public override void dispose () {
        if (child != null) {
            child.unparent ();
            child = null;
        }
        base.dispose ();
    }

    public signal void dismissed ();

    public void set_can_dismiss (bool state) {
        swipe_tracker.set_enabled (state);
    }

    /*
     * Overrides
     */

    protected override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    protected override void measure (Gtk.Orientation orientation, int for_size,
                                     out int minimum, out int natural,
                                     out int minimum_baseline, out int natural_baseline) {
        minimum = 0;
        natural = 0;
        minimum_baseline = -1;
        natural_baseline = -1;

        if (child == null || !child.should_layout ()) {
            return;
        }

        child.measure (orientation, for_size,
                       out minimum, out natural, null, null);
    }

    protected override void size_allocate (int width, int height, int baseline) {
        if (child == null || !child.should_layout ()) {
            return;
        }

        int child_width = width;
        int child_height = height;

        double x = 0;
        if (get_direction () == Gtk.TextDirection.RTL) {
            x -= (width * swipe_progress);
        } else {
            x += (width * swipe_progress);
        }

        Gsk.Transform transform = new Gsk.Transform ()
                                   .translate (Graphene.Point ().init ((float) x, 0));

        child.allocate (child_width, child_height, baseline, transform);
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        snapshot.push_opacity (1 - swipe_progress.abs ());
        snapshot_child (child, snapshot);
        snapshot.pop ();
    }

    /*
     * Callbacks
     */

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
        swipe_progress = distance;
    }

    private void swipe_end_swipe_cb (double velocity, double to) {
        if (!gesture_active) {
            return;
        }

        animation.set_value_from (swipe_progress);
        animation.set_value_to (to);
        animation.set_initial_velocity (velocity);

        // Disable user input if dismissed
        set_can_target (to == 0);

        animation.play ();

        gesture_active = false;
    }

    /*
     * Methods
     */

    public void set_gesture_direction (SwipeDirection swipe_direction) {
        this.swipe_direction = swipe_direction;
        // Reset the position
        swipe_progress = 0.0;
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
        if (!transition_running) {
            return 0;
        }
        return this.swipe_progress;
    }

    /** Gets the snap points of this. */
    public double[] get_snap_points () {
        switch (swipe_direction) {
            case SwipeDirection.SWIPE_LEFT:
                return new double[] { -1, 0 };
            default:
            case SwipeDirection.SWIPE_RIGHT:
                return new double[] { 0, 1 };
        }
    }

    /**
     * Gets the area this can start a swipe from for the given direction
     * and gesture type.
     */
    public Gdk.Rectangle get_swipe_area (Adw.NavigationDirection direction,
                                         bool is_drag) {
        Gtk.Allocation alloc = Gtk.Allocation ();
        Graphene.Rect bounds;
        this.compute_bounds (this, out bounds);
        alloc.width = (int) bounds.size.width;
        alloc.height = (int) bounds.size.height;
        alloc.x = (int) bounds.origin.x;
        alloc.y = (int) bounds.origin.y;

        return alloc;
    }
}
