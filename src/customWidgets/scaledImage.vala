namespace SwayNotificationCenter {
    public class ScaledImage : Gtk.Widget {
        private Gdk.Texture ? texture;
        private Gtk.Image image;

        public ScaledImage () {
            this.set_overflow (Gtk.Overflow.HIDDEN);

            this.image = new Gtk.Image ();
            this.image.set_parent (this);

            this.layout_manager = new Gtk.BinLayout ();
        }

        public override void snapshot (Gtk.Snapshot snap) {
            if (texture == null) {
                base.snapshot (snap);
                return;
            }

            Functions.snapshot_apply_scaled_texture (snap, texture,
                                                     get_width (), get_height (),
                                                     scale_factor);
        }

        public void set_pixel_size (int pixel_size) {
            image.set_pixel_size (pixel_size);
        }

        public void set_from_texture (owned Gdk.Texture texture) {
            this.texture = texture;
            queue_draw ();
        }

        public void set_from_pixbuf (Gdk.Pixbuf ? pixbuf) {
            if (pixbuf != null) {
                this.texture = Gdk.Texture.for_pixbuf (pixbuf);
            } else {
                this.texture = null;
            }
            queue_draw ();
        }

        public void set_from_gicon (Icon icon) {
            texture = null;
            image.set_from_gicon (icon);
        }

        public void set_from_icon_name (string ? icon_name) {
            texture = null;
            image.set_from_icon_name (icon_name);
        }
    }
}
