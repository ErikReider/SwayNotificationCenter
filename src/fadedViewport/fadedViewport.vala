namespace SwayNotificationCenter {
    public class FadedViewport : Gtk.Viewport {
        private int fade_height;

        public FadedViewport (int fade_height) {
            this.fade_height = fade_height;
        }

        public override void size_allocate (Gtk.Allocation allocation) {
            base.size_allocate (allocation);

            unowned Gtk.Widget ? child = get_child ();

            if (child == null) return;

            uint border_width = get_border_width ();

            if (child.get_visible ()) {
                int height;
                child.get_preferred_height_for_width (allocation.width,
                                                       out height, null);

                // TODO: Compensate for fade offset
                Gtk.Allocation alloc = Gtk.Allocation ();
                alloc.x = allocation.x + (int) border_width;
                alloc.y = (int) (allocation.y + border_width);
                alloc.width = allocation.width - 2 * (int) border_width;
                alloc.height = height - 2 * (int) border_width;

                child.size_allocate (alloc);

                if (get_realized ()) {
                    child.show ();
                }
            }
            if (get_realized ()) {
                child.set_child_visible (true);
            }
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
