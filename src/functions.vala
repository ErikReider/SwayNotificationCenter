namespace SwayNotificationCenter {
    public class Functions {
        public static void set_image_path (owned string path,
                                           Gtk.Image img,
                                           int icon_size,
                                           bool file_exists) {
            if ((path.length > 6 && path.slice (0, 7) == "file://") || file_exists) {
                // Try as a URI (file:// is the only URI schema supported right now)
                try {
                    if (!file_exists) path = path.slice (7, path.length);

                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale (
                        path,
                        icon_size * img.scale_factor,
                        icon_size * img.scale_factor,
                        true);
                    var surface = Gdk.cairo_surface_create_from_pixbuf (
                        pixbuf,
                        img.scale_factor,
                        img.get_window ());
                    img.set_from_surface (surface);
                    return;
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
            } else if (Gtk.IconTheme.get_default ().has_icon (path)) {
                // Try as a freedesktop.org-compliant icon theme
                img.set_from_icon_name (path, Notification.icon_size);
            } else {
                img.set_from_icon_name (
                    "image-missing",
                    Notification.icon_size);
            }
        }

        public static void set_image_data (ImageData data, Gtk.Image img, int icon_size) {
            // Rebuild and scale the image
            var pixbuf = new Gdk.Pixbuf.with_unowned_data (data.data,
                                                           Gdk.Colorspace.RGB,
                                                           data.has_alpha,
                                                           data.bits_per_sample,
                                                           data.width,
                                                           data.height,
                                                           data.rowstride,
                                                           null);

            pixbuf = pixbuf.scale_simple (
                icon_size * img.scale_factor,
                icon_size * img.scale_factor,
                Gdk.InterpType.BILINEAR);
            var surface = Gdk.cairo_surface_create_from_pixbuf (
                pixbuf,
                img.scale_factor,
                img.get_window ());
            img.set_from_surface (surface);
        }

        public static bool load_css (string ? style_path) {
            try {
                Gtk.CssProvider css_provider = new Gtk.CssProvider ();
                css_provider.load_from_path (get_style_path (style_path));
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (),
                    css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                return true;
            } catch (Error e) {
                print ("Error: %s\n", e.message);
            }
            return false;
        }

        public static string get_style_path (string ? custom_path) {
            string[] paths = {};
            if (custom_path != null && custom_path.length > 0) {
                paths += custom_path;
            }
            paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                      GLib.Environment.get_user_config_dir (),
                                      "swaync/style.css");

            foreach (var path in GLib.Environment.get_system_config_dirs ()) {
                paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                          path, "swaync/style.css");
            }

            string path = "";
            foreach (string try_path in paths) {
                if (File.new_for_path (try_path).query_exists ()) {
                    path = try_path;
                    break;
                }
            }
            if (path == "") {
                stderr.printf (
                    "COULD NOT FIND CSS FILE! REINSTALL THE PACKAGE!\n");
                Process.exit (1);
            }
            return path;
        }

        public static string get_config_path (string ? custom_path) {
            string[] paths = {};
            if (custom_path != null && custom_path.length > 0) {
                paths += custom_path;
            }
            paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                      GLib.Environment.get_user_config_dir (),
                                      "swaync/config.json");
            foreach (var path in GLib.Environment.get_system_config_dirs ()) {
                paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                          path, "swaync/config.json");
            }

            string path = "";
            foreach (string try_path in paths) {
                if (File.new_for_path (try_path).query_exists ()) {
                    path = try_path;
                    break;
                }
            }
            if (path == "") {
                stderr.printf (
                    "COULD NOT FIND CONFIG FILE! REINSTALL THE PACKAGE!\n");
                Process.exit (1);
            }
            return path;
        }

        public static string get_match_from_info (MatchInfo info) {
            var all = info.fetch_all ();
            if (all.length > 1 && all[1].length > 0) {
                string img = all[1];
                // Replaces "~/" with $HOME
                if (img.index_of ("~/", 0) == 0) {
                    img = GLib.Environment.get_home_dir () +
                          img.slice (1, img.length);
                }
                return img;
            }
            return "";
        }

        /** Gets the base type of a type if it's derivited */
        public static Type get_base_type (Type type) {
            if (type.is_derived ()) {
                while (type.is_derived ()) {
                    type = type.parent ();
                }
            }
            return type;
        }
    }
}
