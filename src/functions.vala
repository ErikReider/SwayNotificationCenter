namespace SwayNotificatonCenter {
    public class Functions {
        public static void set_image_path (owned string path, Gtk.Image img) {
            if (path.slice (0, 7) == "file://") {
                try {
                    path = path.slice (7, path.length);
                    var pixbuf = new Gdk.Pixbuf.from_file_at_size (path, 48, 48);
                    img.set_from_pixbuf (pixbuf);
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                    img.set_from_icon_name ("image-missing", Gtk.IconSize.DIALOG);
                }
                return;
            }
            img.set_from_icon_name (path, Gtk.IconSize.DIALOG);
        }

        public static void set_image_data (Image_Data data, Gtk.Image img) {
            // Rebuild and scale the image
            var pixbuf = new Gdk.Pixbuf.with_unowned_data (data.data, Gdk.Colorspace.RGB,
                                                           data.has_alpha, data.bits_per_sample,
                                                           data.width, data.height, data.rowstride, null);
            var scaled_pixbuf = pixbuf.scale_simple (64, 64, Gdk.InterpType.BILINEAR);
            img.set_from_pixbuf (scaled_pixbuf);
        }
    }
}
