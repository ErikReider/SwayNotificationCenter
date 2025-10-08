public class AnimatedListItem : Gtk.Widget {
    public const int DEFAULT_ANIMATION_DURATION = 350;

    public enum RevealAnimationType {
        NONE, SLIDE, SLIDE_WITH
    }

    public enum ChildAnimationType {
        NONE, SLIDE_FROM_LEFT, SLIDE_FROM_RIGHT
    }

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
    public int animation_duration { get; construct set; }
    public Adw.Easing animation_easing { get; construct set; }
    public RevealAnimationType animation_reveal_type { get; construct set; }
    public ChildAnimationType animation_child_type { get; construct set; }
    public bool animation_child_fade { get; construct set; }
    public bool destroying { get; private set; default = false; }

    private Adw.TimedAnimation animation;
    private double animation_value = 1.0;
    private ulong animation_done_cb_id = 0;
    private unowned SourceFunc ? removed_cb = null;
    private unowned SourceFunc ? added_cb = null;

    public AnimatedListItem () {
        Object (
            css_name: "animatedlistitem",
            accessible_role: Gtk.AccessibleRole.LIST_ITEM,
            overflow: Gtk.Overflow.HIDDEN,
            animation_duration: DEFAULT_ANIMATION_DURATION,
            animation_easing: Adw.Easing.EASE_OUT_QUINT,
            animation_reveal_type: RevealAnimationType.SLIDE,
            animation_child_type: ChildAnimationType.SLIDE_FROM_RIGHT,
            animation_child_fade: true
        );

        Adw.CallbackAnimationTarget target = new Adw.CallbackAnimationTarget (set_animation_value);
        animation = new Adw.TimedAnimation (this, 0.0, 1.0, animation_duration, target);
        bind_property ("animation-easing",
                       animation, "easing",
                       BindingFlags.SYNC_CREATE, null, null);
    }

    public override void dispose () {
        if (child != null) {
            child.unparent ();
            child = null;
        }

        base.dispose ();
    }

    public override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void size_allocate (int width,
                                        int height,
                                        int baseline) {
        if (child == null || !child.should_layout ()) {
            return;
        }

        if (animation_value >= 1) {
            child.allocate (width, height, baseline, null);
        } else if (animation_value < 0) {
            return;
        }

        int child_width = width;
        int child_height = height;
        if (animation_value < 1.0) {
            int min, nat;
            child.measure (Gtk.Orientation.VERTICAL, width,
                           out min, out nat, null, null);
            if (Math.ceil (nat * animation_value) == height) {
                child_height = nat;
            } else if (Math.ceil (min * animation_value) == height) {
                child_height = min;
            } else {
                double d = Math.floor (height / animation_value);
                child_height = int.min ((int) d, int.MAX);
            }
        }

        Gsk.Transform transform = new Gsk.Transform ();
        switch (animation_reveal_type) {
            case RevealAnimationType.SLIDE_WITH:
                transform = transform.translate_3d (
                    Graphene.Point3D ().init (0, height - child_height, 0)
                );
                break;
            case RevealAnimationType.SLIDE:
            case RevealAnimationType.NONE:
                break;
        }
        switch (animation_child_type) {
            case ChildAnimationType.SLIDE_FROM_RIGHT:
                transform = transform.translate_3d (
                    Graphene.Point3D ()
                        .init (child_width * (float) (1 - animation_value), 0, 0)
                );
                break;
            case ChildAnimationType.SLIDE_FROM_LEFT:
                transform = transform.translate_3d (
                    Graphene.Point3D ()
                        .init (-child_width * (float) (1 - animation_value), 0, 0)
                );
                break;
            case ChildAnimationType.NONE:
                break;
        }

        child.allocate (child_width, child_height, -1, transform);
    }

    public override void measure (Gtk.Orientation orientation,
                                  int for_size,
                                  out int minimum,
                                  out int natural,
                                  out int minimum_baseline,
                                  out int natural_baseline) {
        minimum = 0;
        natural = 0;
        minimum_baseline = -1;
        natural_baseline = -1;

        if (child == null || !child.should_layout ()) {
            return;
        }

        child.measure (orientation, for_size,
                       out minimum, out natural, null, null);

        switch (orientation) {
            case Gtk.Orientation.HORIZONTAL:
                break;
            case Gtk.Orientation.VERTICAL:;
                minimum = (int) Math.ceil (minimum * animation_value);
                natural = (int) Math.ceil (natural * animation_value);
                break;
        }
    }

    public override void snapshot (Gtk.Snapshot snapshot) {
        if (!child.should_layout ()) {
            return;
        }

        if (animation_child_fade) {
            snapshot.push_opacity (animation_value);
        }

        snapshot_child (child, snapshot);

        if (animation_child_fade) {
            snapshot.pop ();
        }
    }

    private void set_animation_value (double value) {
        animation_value = value;
        queue_resize ();
    }

    private inline void remove_animation_done_cb () {
        if (animation_done_cb_id != 0) {
            animation.disconnect (animation_done_cb_id);
            animation_done_cb_id = 0;
        }
    }

    delegate void animation_done (Adw.Animation animation);
    private void set_animation_done_cb (animation_done handler) {
        remove_animation_done_cb ();
        animation_done_cb_id = animation.done.connect (handler);
    }

    private void added_finished_cb () {
        if (added_cb != null) {
            added_cb ();
            added_cb = null;
        }
    }

    public async void added (bool transition) {
        if (added_cb != null) {
            // Already running animation
            return;
        }

        remove_animation_done_cb ();

        if (get_mapped () && transition) {
            set_animation_done_cb (added_finished_cb);
            added_cb = added.callback;
            animation.value_from
                = animation.state == Adw.AnimationState.PLAYING
                    ? animation_value : 0.0;
            animation.value_from = animation.value;
            animation.value_to = 1.0;
            animation.play ();
            yield;
        } else {
            set_animation_value (1.0);
            added_finished_cb ();
        }
    }

    private void removed_finised_cb () {
        if (removed_cb != null) {
            removed_cb ();
            removed_cb = null;
        }
    }

    public async bool removed (bool transition) {
        if (removed_cb != null) {
            // Already running animation
            return false;
        }

        remove_animation_done_cb ();

        set_can_focus (false);
        set_can_target (false);

        if (get_mapped () && transition) {
            set_animation_done_cb (removed_finised_cb);
            removed_cb = removed.callback;
            animation.value_from
                = animation.state == Adw.AnimationState.PLAYING
                    ? animation_value : 1.0;
            animation.value_to = 0.0;
            destroying = true;
            animation.play ();
            yield;
        } else {
            set_animation_value (0.0);
            removed_finised_cb ();
        }

        if (child != null) {
            child.unparent ();
            child = null;
        }
        // Fixes the animation keeping a reference of the widget
        animation = null;

        return true;
    }
}
