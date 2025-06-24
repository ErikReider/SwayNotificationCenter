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

    private Adw.CallbackAnimationTarget target;
    private Adw.TimedAnimation animation;
    private double animation_value = 0.0;
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

        target = new Adw.CallbackAnimationTarget (animation_value_cb);
        animation = new Adw.TimedAnimation (this, 0.0, 1.0,
                                            animation_duration, target);
        bind_property ("animation-easing",
                       animation, "easing",
                       BindingFlags.SYNC_CREATE, null, null);
    }

    public override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.CONSTANT_SIZE;
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

        if (orientation == Gtk.Orientation.VERTICAL) {
            if (animation_value == 0) {
                return;
            }
        }

        child.measure (orientation, for_size,
                       out minimum, out natural, null, null);

        minimum = (int) Math.ceil (minimum * animation_value);
        natural = (int) Math.ceil (natural * animation_value);
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

    private void animation_value_cb (double value) {
        this.animation_value = value;
        queue_resize ();
    }

    private void animation_done_add () {
        if (added_cb != null) {
            added_cb ();
            added_cb = null;
        }
    }
    private void animation_done_remove () {
        unparent ();
        if (removed_cb != null) {
            removed_cb ();
            removed_cb = null;
        }
    }

    private void animation_remove_done_cb () {
        if (animation_done_cb_id != 0) {
            animation.disconnect (animation_done_cb_id);
            animation_done_cb_id = 0;
        }
    }

    delegate void animation_done (Adw.Animation animation);
    private void animation_add_done_cb (animation_done handler) {
        animation_remove_done_cb ();
        animation_done_cb_id = animation.done.connect ((a) => handler (a));
    }

    public async void added (bool transition) {
        if (added_cb != null) {
            // Already running animation
            return;
        }

        animation_remove_done_cb ();

        if (get_mapped () && transition) {
            animation_add_done_cb (animation_done_add);
            added_cb = added.callback;
            animation.value_from
                = animation.state == Adw.AnimationState.PLAYING
                    ? animation_value : 0.0;
            animation.value_from = animation.value;
            animation.value_to = 1.0;
            animation.play ();
            yield;
        } else {
            animation_value = 1.0;
            animation_done_add ();
        }
    }

    public async bool removed (bool transition) {
        if (removed_cb != null) {
            // Already running animation
            return false;
        }

        animation_remove_done_cb ();

        set_can_focus (false);
        set_can_target (false);

        if (get_mapped () && transition) {
            animation_add_done_cb (animation_done_remove);
            removed_cb = removed.callback;
            animation.value_from
                = animation.state == Adw.AnimationState.PLAYING
                    ? animation_value : 1.0;
            animation.value_to = 0.0;
            destroying = true;
            animation.play ();
            yield;
        } else {
            animation_value = 0.0;
            animation_done_remove ();
        }

        return true;
    }
}
