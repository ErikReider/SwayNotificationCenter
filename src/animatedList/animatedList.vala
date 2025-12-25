public enum AnimatedListDirection {
    TOP_TO_BOTTOM, BOTTOM_TO_TOP;
}

private struct AnimationData {
    public Gtk.Adjustment vadj;
    public unowned AnimatedListItem item;
}

private struct WidgetHeights {
    int min_height;
    int nat_height;
}

private struct WidgetAlloc {
    float y;
    int height;

    public WidgetAlloc () {
        y = 0;
        height = 0;
    }
}

private class AnimationValueTarget : Object {
    private double _progress = 0;
    public double progress {
        get {
            return _progress;
        }
        set {
            _progress = value;
            cb (_progress);
        }
    }

    public delegate void callback (double value);

    private unowned callback ?cb;

    public AnimationValueTarget (float init_value, callback cb) {
        this._progress = init_value;
        this.cb = cb;
    }

    public Adw.PropertyAnimationTarget get_animation_target () {
        return new Adw.PropertyAnimationTarget (this, "progress");
    }
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
    public unowned List<unowned AnimatedListItem> visible_children {
        get;
        private construct set;
    }

    /**
     * Indicates if new / removed children should display an expand and shrink
     * animation.
     */
    public bool transition_children { get; construct set; }
    /** Whether or not the list should display its items in a stack or not */
    public bool use_card_animation { get; construct set; }
    /** The direction that the items should flow in */
    public AnimatedListDirection direction { get; construct set; }
    /** Scroll to the latest item added to the list */
    public bool scroll_to_append { get; construct set; }
    /** The default item reveal animation type */
    public AnimatedListItem.RevealAnimationType animation_reveal_type {
        get;
        construct set;
    }
    /** The default item animation type */
    public AnimatedListItem.ChildAnimationType animation_child_type {
        get;
        construct set;
    }

    // Scroll bottom animation
    Adw.CallbackAnimationTarget scroll_btm_target;
    Adw.TimedAnimation scroll_btm_anim;
    AnimationData ?scroll_btm_anim_data = null;

    // Scroll top animation
    Adw.CallbackAnimationTarget scroll_top_target;
    Adw.TimedAnimation scroll_top_anim;
    AnimationData ?scroll_top_anim_data = null;

    // Adding an item to the top compensation
    Adw.CallbackAnimationTarget scroll_comp_target;
    Adw.TimedAnimation scroll_comp_anim;
    AnimationData ?scroll_comp_anim_data = null;

    // When true, the size_allocate method will scroll to the top/bottom
    private bool set_initial_scroll_value = false;
    private float fade_distance = 0.0f;
    private unowned Gtk.Settings settings = Gtk.Settings.get_default ();

    construct {
        hadjustment = null;

        children = new List<AnimatedListItem> ();
        visible_children = new List<unowned AnimatedListItem> ();

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
            css_name : "animatedlist",
            accessible_role : Gtk.AccessibleRole.LIST,
            transition_children : true,
            use_card_animation: true,
            direction: AnimatedListDirection.TOP_TO_BOTTOM,
            scroll_to_append: false
        );
    }

    public override void dispose () {
        foreach (AnimatedListItem child in children) {
            transition_children = false;
            remove.begin (child, false);
        }

        base.dispose ();
    }

    public bool get_border (out Gtk.Border border) {
        border = Gtk.Border ();
        return false;
    }

    protected override Gtk.SizeRequestMode get_request_mode () {
        foreach (unowned AnimatedListItem item in children) {
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

        foreach (unowned AnimatedListItem item in children) {
            hexpand_p |= item.compute_expand (Gtk.Orientation.HORIZONTAL);
            vexpand_p |= item.compute_expand (Gtk.Orientation.VERTICAL);
        }
    }

    private float get_fade_distance (int height) {
        switch (direction) {
            case AnimatedListDirection.TOP_TO_BOTTOM:
                return height - fade_distance;
            case AnimatedListDirection.BOTTOM_TO_TOP:
                return fade_distance;
        }
        return 0;
    }

    private void compute_height (int width,
                                 int height,
                                 out int total_height,
                                 out WidgetAlloc[] child_heights) {
        total_height = 0;
        child_heights = new WidgetAlloc[n_children];

        fade_distance = 0;

        int num_vexpand_children = 0;
        WidgetHeights measured_height = WidgetHeights ();
        WidgetHeights[] heights = new WidgetHeights[n_children];
        int total_min = 0;
        int total_nat = 0;

        int i = 0;
        foreach (AnimatedListItem child in children) {
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
            fade_distance = float.max (
                fade_distance,
                int.min (min_height, nat_height)
            );

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

        int y = 0;
        i = 0;
        foreach (AnimatedListItem child in children) {
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
            child_heights[i] = child_allocation;

            total_height += child_allocation.height;
            y += child_allocation.height;
            i++;
        }

        const float LIMIT = 0.2f;
        if (fade_distance == 0) {
            fade_distance = height * LIMIT;
        } else {
            // Make sure that the fade distance isn't larger than the height
            fade_distance = float.min (fade_distance, height * LIMIT);
        }

        // The padding to add to the bottom/top of the list to compensate
        // for the fade, but only when the list is large enough to allow
        // for scrolling.
        if (should_card_animate () && vadjustment != null && total_height > height) {
            total_height += (int) fade_distance;
        }
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
        WidgetAlloc[] heights;
        compute_height (width, height, out total_height, out heights);

        bool is_reversed = direction == AnimatedListDirection.BOTTOM_TO_TOP;
        bool has_scroll = total_height > height;

        float scroll_y = 0.0f;
        if (vadjustment != null) {
            scroll_y = (float) vadjustment.value;
            // Set the initial scroll value to the top or bottom
            // if the user hasn't scrolled yet.
            if (has_scroll && set_initial_scroll_value) {
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
        total_height = int.max (height, total_height);

        // Allocate the size and position of each item
        uint index = 0;
        foreach (AnimatedListItem child in children) {
            if (!child.should_layout ()) {
                index++;
                continue;
            }

            WidgetAlloc child_allocation = heights[index];
            int child_height = child_allocation.height;

            float scale = 1.0f;
            float x = 0;
            float y = child_allocation.y - scroll_y;
            if (is_reversed) {
                y = total_height - child_height - child_allocation.y - scroll_y;
            }
            float opacity = 1.0f;

            bool skip_child = true;
            if (y < height && child_height + y > 0) {
                skip_child = false;

                // Deck of cards effect
                if (should_card_animate () && has_scroll) {
                    float item_center = y + child_height * 0.5f;
                    // Compensate for very tall items being faded out before seeing the top
                    if (child_height > height) {
                        item_center = y + (is_reversed ? child_height : 0);
                    }
                    // The cut off where to start fade away
                    float local_fade_distance = get_fade_distance (height);
                    if ((!is_reversed && item_center > local_fade_distance)
                        || (is_reversed && item_center < local_fade_distance)) {
                        // The distance from the fade edge
                        float dist = Math.fabsf (item_center - local_fade_distance);

                        // Hide when half way across the "circle".
                        // A little trigonometry never killed anybody :-)
                        float radius = fade_distance;
                        if (dist < radius) {
                            float angle = Math.atanf (dist / radius);
                            // The Y value within the circle (dot product)
                            float new_y = Math.sinf (angle) * radius;
                            // The ratio between the untransformed height and the dot product height
                            scale = 1.0f - (new_y / height * 2);
                            // Center the item in the X axis
                            x = (width - (width * scale)) * 0.5f;
                            // Calculate the new distance from the start of the fade
                            // NOTE: Reverse the direction of the animation
                            // depending on the list direction.
                            y += (float) (dist * Math.sin (angle) * (is_reversed ? 1 : -1));
                            opacity = 1.0f - (dist / radius * 2);

                            skip_child |= opacity <= 0.1;
                        } else {
                            skip_child = true;
                        }
                    }
                }
            }

            // Only display visible items
            if (!skip_child
                && y < height && child_height + y > 0) {
                // Prepend the child so that the child can be rendered first
                // (to maintain a reversed z-index)
                visible_children.prepend (child);
            }

            Gsk.Transform transform = new Gsk.Transform ()
                 .translate (Graphene.Point ().init (x, y))
                 .scale (scale, scale);
            child.allocate (width, child_height, baseline, transform);
            child.set_opacity (opacity);

            index++;
        }

        if (vadjustment != null) {
            vadjustment.configure (scroll_y,
                                   0, total_height,
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

        int min = 0, nat = 0;
        int largest_min = 0, largest_nat = 0;
        foreach (AnimatedListItem child in children) {
            if (!child.should_layout ()) {
                continue;
            }

            int child_min, child_nat;
            child.measure (orientation, for_size,
                           out child_min, out child_nat, null, null);
            min += child_min;
            nat += child_nat;
            largest_min = int.max (largest_min, child_min);
            largest_nat = int.max (largest_min, child_nat);
        }

        switch (orientation) {
            case Gtk.Orientation.HORIZONTAL:
                minimum = largest_min;
                natural = largest_nat;
                break;
            case Gtk.Orientation.VERTICAL:
                minimum = min;
                natural = nat;
                break;
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
        return new Gtk.Adjustment (
            original.get_value (),
            original.get_lower (),
            original.get_upper (),
            original.get_step_increment (),
            original.get_page_increment (),
            original.get_page_size ()
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

            // Set the defaults
            item.animation_reveal_type = animation_reveal_type;
            item.animation_child_type = animation_child_type;

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
    public async AnimatedListItem ?prepend (Gtk.Widget widget) {
        if (widget == null || widget.parent != null) {
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
    public async AnimatedListItem ?append (Gtk.Widget widget) {
        if (widget == null || widget.parent != null) {
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
                case AnimatedListDirection.TOP_TO_BOTTOM :
                    play_scroll_top_anim (item);
                    break;
                case AnimatedListDirection.BOTTOM_TO_TOP :
                    play_scroll_bottom_anim (item);
                    break;
            }
        }

        yield item.added (transition_children);

        return item;
    }

    private AnimatedListItem ?try_get_ancestor (Gtk.Widget widget) {
        AnimatedListItem item;
        if (widget is AnimatedListItem) {
            item = widget as AnimatedListItem;
        } else if (widget.parent is AnimatedListItem) {
            item = widget.parent as AnimatedListItem;
        } else {
            unowned Gtk.Widget ?ancestor
                = widget.get_ancestor (typeof (AnimatedListItem));
            if (!(ancestor is AnimatedListItem)) {
                warning ("Widget %p of type  \"%s\" is not an ancestor of %s!",
                         widget, widget.get_type ().name (),
                         typeof (AnimatedListItem).name ());
                return null;
            }
            item = ancestor as AnimatedListItem;
        }

        if (item.parent != this) {
            warn_if_reached ();
            return null;
        }
        return item;
    }

    public async bool remove (Gtk.Widget widget, bool transition) {
        if (widget == null) {
            warn_if_reached ();
            return false;
        }

        AnimatedListItem ?item = try_get_ancestor (widget);
        if (item == null) {
            warn_if_reached ();
            return false;
        }

        // Will unparent itself when done animating
        if (!yield item.removed (transition_children && transition)) {
            debug ("Skipping extra removal of AnimatedListItem");
            return false;
        }

        item.unparent ();
        children.remove (item);
        n_children--;

        // Make sure that we don't render/compute the bounds of this destroyed widget.
        // queue_resize might not finish in-time before iterating the visible children
        unowned List<unowned AnimatedListItem> visible_item = visible_children.find (item);
        if (visible_item != null) {
            visible_children.delete_link (visible_item);
        }

        queue_resize ();
        return true;
    }

    public bool move_to_beginning (Gtk.Widget widget, bool scroll_to) {
        if (widget == null) {
            warn_if_reached ();
            return false;
        }

        AnimatedListItem ?item = try_get_ancestor (widget);
        if (item == null) {
            warn_if_reached ();
            return false;
        }

        // move to the beginning of the list
        item.insert_after (this, null);
        children.remove (item);
        children.prepend (item);

        queue_resize ();

        if (scroll_to) {
            scroll_to_top ();
        }

        return true;
    }

    private uint scroll_to_source_id = 0;
    public void scroll_to_top () {
        if (scroll_to_source_id > 0) {
            Source.remove (scroll_to_source_id);
        }
        scroll_to_source_id = Idle.add_once (() => {
            scroll_to_source_id = 0;

            unowned AnimatedListItem ?item = get_first_item ();
            return_if_fail (item != null);
            switch (direction) {
                case AnimatedListDirection.TOP_TO_BOTTOM :
                    play_scroll_top_anim (item);
                    break;
                case AnimatedListDirection.BOTTOM_TO_TOP :
                    play_scroll_bottom_anim (item);
                    break;
            }
        });
    }

    public bool is_empty () {
        return children.is_empty ();
    }

    public unowned AnimatedListItem ?get_first_item () {
        if (children.is_empty ()) {
            return null;
        }
        return children.first ().data;
    }

    public unowned AnimatedListItem ?get_last_item () {
        if (children.is_empty ()) {
            return null;
        }
        return children.last ().data;
    }

    private bool should_card_animate () {
        bool value = this.use_card_animation;
        if (settings != null) {
            value &= settings.gtk_enable_animations;
        }
        return value;
    }
}
