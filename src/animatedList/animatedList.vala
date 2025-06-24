public enum AnimatedListDirection {
    TOP_TO_BOTTOM, BOTTOM_TO_TOP;
}

private struct AnimationData {
    public Gtk.Adjustment vadj;
    public unowned AnimatedListItem item;
}

public class AnimatedList : Gtk.Widget, Gtk.Scrollable {
    public const int SCROLL_ANIMATION_DURATION = 500;

    public Gtk.Adjustment hadjustment { get; set construct; }
    public Gtk.ScrollablePolicy hscroll_policy { get; set; }
    public Gtk.Adjustment vadjustment { get; set construct; }
    public Gtk.ScrollablePolicy vscroll_policy { get; set; }

    public uint n_children { get; private set; }
    public unowned List<AnimatedListItem> children {
        get;
        private construct set;
    }
    private List<unowned AnimatedListItem> visible_children
        = new List<unowned AnimatedListItem> ();

    /**
     * Indicates if new / removed children should display an expand and shrink
     * animation.
     */
    public bool transition_children { get; construct set; }
    /** Whether or not the list should display its items in a stack or not */
    public bool use_card_animation { get; construct set; }
    /** The direction that the items should flow in */
    public AnimatedListDirection direction { get; construct set; }
    // TODO: Scroll to widget/bottom/top append/prepend
    /** Scroll to the latest item added to the list */
    public bool scroll_to_append { get; construct set; }

    // Scroll bottom animation
    Adw.CallbackAnimationTarget scroll_btm_target;
    Adw.TimedAnimation scroll_btm_anim;
    AnimationData ? scroll_btm_anim_data = null;

    // Scroll top animation
    Adw.CallbackAnimationTarget scroll_top_target;
    Adw.TimedAnimation scroll_top_anim;
    AnimationData ? scroll_top_anim_data = null;

    // Adding an item to the top compensation
    Adw.CallbackAnimationTarget scroll_comp_target;
    Adw.TimedAnimation scroll_comp_anim;
    AnimationData ? scroll_comp_anim_data = null;

    // When true, the size_allocate method will scroll to the top/bottom
    private bool set_initial_scroll_value = false;

    construct {
        hadjustment = null;

        children = new List<AnimatedListItem> ();

        notify["vadjustment"].connect (() => {
            if (vadjustment != null) {
                vadjustment.value_changed.connect (() => {
                    queue_allocate ();
                });
            }
        });

        map.connect (() => {
            // Ensures that the initial scroll position gets set after
            // GTK recalculates the layout
            Idle.add_once (() => {
                set_initial_scroll_value = true;
                queue_allocate ();
            });
        });

        set_overflow (Gtk.Overflow.HIDDEN);

        scroll_btm_target = new Adw.CallbackAnimationTarget (scroll_bottom_value_cb);
        scroll_btm_anim = new Adw.TimedAnimation (
            this, 0.0, 1.0, SCROLL_ANIMATION_DURATION, scroll_btm_target);
        scroll_btm_anim.set_easing (Adw.Easing.EASE_OUT_QUINT);

        scroll_top_target = new Adw.CallbackAnimationTarget (scroll_top_value_cb);
        scroll_top_anim = new Adw.TimedAnimation (
            this, 0.0, 1.0, SCROLL_ANIMATION_DURATION, scroll_top_target);
        scroll_top_anim.set_easing (Adw.Easing.EASE_OUT_QUINT);

        scroll_comp_target = new Adw.CallbackAnimationTarget (scroll_comp_value_cb);
        scroll_comp_anim = new Adw.TimedAnimation (
            this, 0.0, 1.0, SCROLL_ANIMATION_DURATION, scroll_comp_target);
        scroll_comp_anim.set_easing (Adw.Easing.EASE_OUT_QUINT);
    }

    public AnimatedList () {
        Object (
            css_name: "animatedlist",
            accessible_role: Gtk.AccessibleRole.LIST,
            transition_children: true,
            use_card_animation: true,
            direction: AnimatedListDirection.TOP_TO_BOTTOM,
            scroll_to_append: false
        );
    }

    public override void dispose () {
        foreach (AnimatedListItem child in children) {
            transition_children = false;
            remove.begin (child);
        }
    }

    public bool get_border (out Gtk.Border border) {
        border = Gtk.Border ();
        return false;
    }

    public override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.CONSTANT_SIZE;
    }

    private float get_base_fade_distance (int height) {
        return float.min (height * 0.3f, 75);
    }

    private float get_fade_distance (int height) {
        switch (direction) {
            case AnimatedListDirection.TOP_TO_BOTTOM:
                return height - get_base_fade_distance (height);
            case AnimatedListDirection.BOTTOM_TO_TOP:
                return get_base_fade_distance (height);
        }
        return 0;
    }

    private void get_total_height (out int[] heights,
                                   out int total_height) {
        heights = new int[n_children];
        total_height = 0;

        int i = 0;
        foreach (AnimatedListItem child in children) {
            if (!child.should_layout ()) {
                continue;
            }

            int nat;
            child.measure (Gtk.Orientation.VERTICAL, -1,
                           null, out nat, null, null);
            heights[i] = nat;
            total_height += nat;
            i++;
        }
    }

    private float easing (float x) {
        return x * x * x;
    }

    protected override void size_allocate (int width,
                                           int height,
                                           int baseline) {
        // Recalculate which children are visible, so clear the old list
        while (!visible_children.is_empty ()) {
            visible_children.delete_link (visible_children.nth (0));
        }
        warn_if_fail (visible_children.is_empty ());

        // Save the already computed widget heights. We need the total height
        // for calculating the reversed list animation, so two loops through the
        // widgets is necessary...
        int total_height;
        int[] heights;
        get_total_height (out heights, out total_height);

        bool is_reversed = direction == AnimatedListDirection.BOTTOM_TO_TOP;
        bool has_scroll = total_height > height;

        // The cut off where to start fade away
        float fade_distance = get_fade_distance (height);
        // The padding to add to the bottom/top of the list to compensate
        // for the fade
        float fade_padding = 0;
        if (use_card_animation) {
            fade_padding = get_base_fade_distance (height) / 2;
        }

        float scroll_y = 0.0f;
        if (vadjustment != null) {
            scroll_y = (float) vadjustment.value;
            if (has_scroll) {
                total_height += (int) fade_padding;

                // Set the initial scroll value to the top or bottom
                // if the user hasn't scrolled yet.
                if (set_initial_scroll_value) {
                    if (get_mapped ()) {
                        set_initial_scroll_value = false;
                    }
                    switch (direction) {
                        case AnimatedListDirection.TOP_TO_BOTTOM:
                            scroll_y = 0;
                            break;
                        case AnimatedListDirection.BOTTOM_TO_TOP:
                            scroll_y = total_height - height;
                            break;
                    }
                }
            }
        }

        // The total un-scaled height of all children
        float prev_child_height = 0;
        // Same as total_height, but with the scaled items.
        // Increases every iteration.
        float y_offset = 0;
        // Allocate the size and position of each item
        uint index = 0;
        foreach (AnimatedListItem child in children) {
            if (!child.should_layout ()) {
                continue;
            }

            int child_nat = heights[index];

            float y_shift = 0.0f;
            float scale = 1.0f;
            float x = 0;
            float y = y_offset - scroll_y;
            if (is_reversed) {
                y = total_height - child_nat - y_offset - scroll_y;
            }
            float opacity = 1.0f;

            if (y < height && child_nat + y > 0) {
                // Prepend the child so that the child can be rendered first
                // (to maintain a reversed z-index)
                visible_children.prepend (child);

                // Deck of cards effect
                if (use_card_animation && has_scroll) {
                    float item_center = y + child_nat * 0.5f;
                    if ((!is_reversed && item_center > fade_distance)
                        || (is_reversed && item_center < fade_distance)) {
                        float fade = is_reversed ? (height - fade_distance) : fade_distance;
                        // The distance from the fade edge
                        float dist = Math.fabsf(item_center - fade_distance);
                        scale = 1.0f - (dist / fade).clamp (0.0f, 1.0f) * 0.5f;
                        x = (width - (width * scale)) * 0.5f;

                        float ease = easing (scale * scale);
                        y_shift = prev_child_height - prev_child_height * ease;
                        opacity = Math.powf (ease, 2);
                    }
                }
            }

            Gsk.Transform transform = new Gsk.Transform ()
                .translate (
                    Graphene.Point ().init (
                        x,
                        // Reverse the direction of the animation depending
                        // on the list direction
                        y + y_shift * (is_reversed ? 1 : -1)
                    )
                )
                .scale (scale, scale);
            child.allocate (width, child_nat, baseline, transform);
            child.set_opacity (opacity);

            y_offset += child_nat * scale - y_shift;
            prev_child_height = child_nat * scale;
            index++;
        }

        if (vadjustment != null) {
            vadjustment.configure (scroll_y, 0, total_height,
                                   height * 0.1,
                                   height * 0.9,
                                   height);
        }
    }

    protected override void measure (Gtk.Orientation orientation,
                                     int for_size,
                                     out int minimum,
                                     out int natural,
                                     out int minimum_baseline,
                                     out int natural_baseline) {
        minimum = 0;
        natural = 0;
        minimum_baseline = -1;
        natural_baseline = -1;

        foreach (AnimatedListItem child in children) {
            if (!child.should_layout ()) {
                continue;
            }

            int child_min, child_nat;
            child.measure (orientation, for_size,
                           out child_min, out child_nat, null, null);
            minimum += child_min;
            natural += child_nat;
        }
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        // Only render the visible items, backwards to retain a valid z-index
        foreach (unowned AnimatedListItem child in visible_children) {
            if (!child.should_layout ()) {
                continue;
            }
            snapshot_child (child, snapshot);
        }
    }

    private Gtk.Adjustment clone_adjustment (Gtk.Adjustment original) {
        return new Gtk.Adjustment(
            original.get_value(),
            original.get_lower(),
            original.get_upper(),
            original.get_step_increment(),
            original.get_page_increment(),
            original.get_page_size()
        );
    }

    private void scroll_bottom_value_cb (double value) {
        vadjustment.set_value (
            scroll_btm_anim_data.vadj.upper - scroll_btm_anim_data.vadj.page_size
            + scroll_btm_anim_data.item.get_height ());
    }

    private void play_scroll_bottom_anim (AnimatedListItem item) {
        scroll_btm_anim_data = AnimationData () {
            item = item,
            vadj = clone_adjustment (vadjustment),
        };
        scroll_top_anim.duration = item.animation_duration;
        scroll_top_anim.easing = item.animation_easing;
        scroll_btm_anim.value_from = 0.0;
        scroll_btm_anim.value_to = 1.0;
        scroll_btm_anim.play ();
    }

    private void scroll_top_value_cb (double value) {
        vadjustment.set_value (
            Adw.lerp (scroll_top_anim_data.vadj.value, 0, value));
    }

    private void play_scroll_top_anim (AnimatedListItem item) {
        scroll_top_anim_data = AnimationData () {
            item = item,
            vadj = clone_adjustment (vadjustment),
        };
        scroll_top_anim.duration = item.animation_duration;
        scroll_top_anim.easing = item.animation_easing;
        scroll_top_anim.value_from = 0.0;
        scroll_top_anim.value_to = 1.0;
        scroll_top_anim.play ();
    }

    private void scroll_comp_value_cb (double value) {
        vadjustment.set_value (
            scroll_comp_anim_data.vadj.value
            + scroll_comp_anim_data.item.get_height ());
    }

    private void play_scroll_comp_anim (AnimatedListItem item) {
        scroll_comp_anim_data = AnimationData () {
            item = item,
            vadj = clone_adjustment (vadjustment),
        };
        scroll_comp_anim.duration = item.animation_duration;
        scroll_comp_anim.easing = Adw.Easing.LINEAR;
        scroll_comp_anim.value_from = 0.0;
        scroll_comp_anim.value_to = 1.0;
        scroll_comp_anim.play ();
    }

    private AnimatedListItem get_list_item (Gtk.Widget widget) {
        AnimatedListItem item;
        if (widget is AnimatedListItem) {
            item = widget as AnimatedListItem;
        } else {
            item = new AnimatedListItem ();
            item.child = widget;

            widget.unparent ();
            widget.set_parent (item);
        }
        return item;
    }

    /**
     * Inserts a widget last into the list depending on direction:
     * TOP_TO_BOTTOM: Bottom
     * BOTTOM_TO_TOP: Top
     */
    public async AnimatedListItem ? prepend (Gtk.Widget widget) {
        if (widget == null) {
            warn_if_reached ();
            return null;
        }

        AnimatedListItem item = get_list_item (widget);
        item.unparent ();
        item.insert_before (this, null); // append

        children.append (item);
        n_children++;

        // Fixes the lack of auto-scrolling when scrolled at the bottom
        // and a new item gets added
        if (direction == AnimatedListDirection.TOP_TO_BOTTOM
            && vadjustment.value == vadjustment.upper - vadjustment.page_size) {
            play_scroll_bottom_anim (item);
        } else if (direction == AnimatedListDirection.BOTTOM_TO_TOP) {
            // Compensate for the scrolling when adding an item to the top of the list
            play_scroll_comp_anim (item);
        }

        yield item.added (transition_children);
        return item;
    }

    /**
     * Inserts a widget first into the list depending on direction:
     * TOP_TO_BOTTOM: Top
     * BOTTOM_TO_TOP: Bottom
     */
    public async AnimatedListItem ? append (Gtk.Widget widget) {
        if (widget == null) {
            warn_if_reached ();
            return null;
        }

        AnimatedListItem item = get_list_item (widget);
        item.unparent ();
        item.insert_after (this, null); // prepend

        children.prepend (item);
        n_children++;

        // Fixes the lack of auto-scrolling when scrolled at the bottom
        // and a new item gets added
        if (direction == AnimatedListDirection.BOTTOM_TO_TOP
            && vadjustment.value == vadjustment.upper - vadjustment.page_size) {
            play_scroll_bottom_anim (item);
        } else if (!scroll_to_append && direction == AnimatedListDirection.TOP_TO_BOTTOM) {
            // Compensate for the scrolling when adding an item to the top of the list
            play_scroll_comp_anim (item);
        } else if (scroll_to_append) {
            // Scrolls to the item if enabled
            switch (direction) {
                case AnimatedListDirection.TOP_TO_BOTTOM:
                    play_scroll_top_anim (item);
                    break;
                case AnimatedListDirection.BOTTOM_TO_TOP:
                    play_scroll_bottom_anim (item);
                    break;
            }
        }

        yield item.added (transition_children);
        return item;
    }

    public async bool remove (Gtk.Widget widget) {
        if (widget == null) {
            warn_if_reached ();
            return false;
        }

        AnimatedListItem item;
        if (widget is AnimatedListItem) {
            item = widget as AnimatedListItem;
        } else if (widget.parent is AnimatedListItem) {
            item = widget.parent as AnimatedListItem;
        } else {
            unowned Gtk.Widget ? ancestor
                = widget.get_ancestor (typeof (AnimatedListItem));
            if (!(ancestor is AnimatedListItem)) {
                warning ("Widget %p of type  \"%s\" is not an ancestor of %s!",
                    widget, widget.get_type ().name (),
                    typeof (AnimatedListItem).name ());
                return false;
            }
            item = ancestor as AnimatedListItem;
        }

        // Will unparent itself when done animating
        bool result = yield item.removed (transition_children);

        children.remove (item);
        n_children--;
        item.destroy ();
        queue_resize ();
        return result;
    }
}
