namespace SwayNotificationCenter {
    public class FadedViewport : Gtk.Viewport {
        private int fade_height = 30;

        private FadedViewportChild container;

        public FadedViewport (int fade_height) {
            if (fade_height > 0) this.fade_height = fade_height;
            this.container = new FadedViewportChild (this.fade_height);

            base.add (container);
        }

        public override void add (Gtk.Widget widget) {
            container.add (widget);
        }

        public override void remove (Gtk.Widget widget) {
            container.remove (widget);
        }

        public override bool draw (Cairo.Context cr) {
            Gtk.Allocation alloc;
            get_allocated_size (out alloc, null);

            Cairo.Pattern top_fade_gradient = new Cairo.Pattern.linear (0, 0, 0, 1);
            top_fade_gradient.add_color_stop_rgba (0, 1, 1, 1, 1);
            top_fade_gradient.add_color_stop_rgba (1, 1, 1, 1, 0);
            Cairo.Pattern bottom_fade_gradient = new Cairo.Pattern.linear (0, 0, 0, 1);
            bottom_fade_gradient.add_color_stop_rgba (0, 1, 1, 1, 0);
            bottom_fade_gradient.add_color_stop_rgba (1, 1, 1, 1, 1);

            cr.save ();
            cr.push_group ();

            // Draw widgets
            base.draw (cr);

            /// Draw vertical fade

            // Top fade
            cr.save ();
            cr.scale (alloc.width, fade_height);
            cr.rectangle (0, 0, alloc.width, fade_height);
            cr.set_source (top_fade_gradient);
            cr.set_operator (Cairo.Operator.DEST_OUT);
            cr.fill ();
            cr.restore ();
            // Bottom fade
            cr.save ();
            cr.translate (0, alloc.height - fade_height);
            cr.scale (alloc.width, fade_height);
            cr.rectangle (0, 0, alloc.width, fade_height);
            cr.set_source (bottom_fade_gradient);
            cr.set_operator (Cairo.Operator.DEST_OUT);
            cr.fill ();
            cr.restore ();

            cr.pop_group_to_source ();
            cr.paint ();
            cr.restore ();
            return true;
        }
    }
}

private class FadedViewportChild : Gtk.Container {
    private int y_padding;

    private unowned Gtk.Widget _child;

    public FadedViewportChild (int y_padding) {
        base.set_has_window (false);
        base.set_can_focus (true);
        base.set_redraw_on_allocate (false);

        // Half due to the fade basically stopping at 50% of the height
        this.y_padding = y_padding / 2;
        this._child = null;

        this.show ();
    }

    public override void add (Gtk.Widget widget) {
        if (this._child == null) {
            widget.set_parent (this);
            this._child = widget;
        }
    }

    public override void remove (Gtk.Widget widget) {
        if (this._child == widget) {
            widget.unparent ();
            this._child = null;
            if (this.get_visible () && widget.get_visible ()) {
                this.queue_resize_no_redraw ();
            }
        }
    }

    public override void forall_internal (bool include_internals, Gtk.Callback callback) {
        if (this._child != null) {
            callback (this._child);
        }
    }

    public override Gtk.SizeRequestMode get_request_mode () {
        if (this._child != null) {
            return this._child.get_request_mode ();
        } else {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }
    }

    public override void size_allocate (Gtk.Allocation allocation) {
        Gtk.Allocation child_allocation = Gtk.Allocation ();
        uint border_width = this.get_border_width ();
        if (this._child != null && this._child.get_visible ()) {
            child_allocation.x = allocation.x + (int) border_width;
            child_allocation.y = allocation.y + (int) border_width;
            Gtk.Align align_y = _child.get_valign ();
            if (align_y == Gtk.Align.END) {
                child_allocation.y -= y_padding;
            } else {
                child_allocation.y += y_padding;
            }
            child_allocation.width = allocation.width - 2 * (int) border_width;
            child_allocation.height = allocation.height - 2 * (int) border_width;
            this._child.size_allocate (child_allocation);
            if (this.get_realized ()) {
                this._child.show ();
            }
        }
        if (this.get_realized ()) {
            if (this._child != null) {
                this._child.set_child_visible (true);
            }
        }
        base.size_allocate (allocation);
    }

    public override void get_preferred_height_for_width (int width,
                                                         out int minimum_height,
                                                         out int natural_height) {
        minimum_height = 0;
        natural_height = 0;

        if (_child != null && _child.get_visible ()) {
            _child.get_preferred_height_for_width (width,
                                                   out minimum_height,
                                                   out natural_height);

            minimum_height += y_padding * 2;
            natural_height += y_padding * 2;
        }
    }

    public override bool draw (Cairo.Context cr) {
        base.draw (cr);
        return false;
    }
}
