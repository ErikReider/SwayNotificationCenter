namespace SwayNotificationCenter {
    public class Functions {
        private static Gtk.CssProvider system_css_provider;
        private static Gtk.CssProvider user_css_provider;

        private Functions () {}

        public static void init () {
            system_css_provider = new Gtk.CssProvider ();
            user_css_provider = new Gtk.CssProvider ();
        }

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

        /** Load the package provided CSS file as a base.
         * Without this, an empty user CSS file would result in widgets
         * with default GTK style properties
         */
        public static bool load_css (string ? style_path) {
            int css_priority = ConfigModel.instance.cssPriority.get_priority ();

            try {
                // Load packaged CSS as backup
                string system_css = get_style_path (null, true);
                system_css_provider.load_from_path (system_css);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (),
                    system_css_provider,
                    css_priority);
            } catch (Error e) {
                print ("Load packaged CSS Error: %s\n", e.message);
                return false;
            }

            try {
                // Load user CSS
                string user_css = get_style_path (style_path);
                user_css_provider.load_from_path (user_css);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (),
                    user_css_provider,
                    css_priority);
                return true;
            } catch (Error e) {
                print ("Load user CSS Error: %s\n", e.message);
                return false;
            }
        }

        public static string get_style_path (owned string ? custom_path,
                                             bool only_system = false) {
            string[] paths = {
                // Fallback location. Specified in postinstall.py
                "/usr/local/etc/xdg/swaync/style.css"
            };
            if (custom_path != null && custom_path.length > 0) {
                // Replaces the home directory relative path with a absolute path
                if (custom_path.get (0) == '~') {
                    custom_path = Environment.get_home_dir () + custom_path[1:];
                }
                paths += custom_path;
            }
            if (!only_system) {
                paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                          Environment.get_user_config_dir (),
                                          "swaync/style.css");
            }

            foreach (var path in Environment.get_system_config_dirs ()) {
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

        public static string get_config_path (owned string ? custom_path) {
            string[] paths = {
                // Fallback location. Specified in postinstall.py
                "/usr/local/etc/xdg/swaync/config.json"
            };
            if (custom_path != null && custom_path.length > 0) {
                // Replaces the home directory relative path with a absolute path
                if (custom_path.get (0) == '~') {
                    custom_path = Environment.get_home_dir () + custom_path[1:];
                }
                paths += custom_path;
            }
            paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                      Environment.get_user_config_dir (),
                                      "swaync/config.json");
            foreach (var path in Environment.get_system_config_dirs ()) {
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
                    img = Environment.get_home_dir () +
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

        /** Scales the pixbuf to fit the given dimensions */
        public static Gdk.Pixbuf scale_round_pixbuf (Gdk.Pixbuf pixbuf,
                                                     int buffer_width,
                                                     int buffer_height,
                                                     int img_scale,
                                                     int radius) {
            Cairo.Surface surface = new Cairo.ImageSurface (Cairo.Format.ARGB32,
                                                            buffer_width,
                                                            buffer_height);
            var cr = new Cairo.Context (surface);

            // Border radius
            const double DEGREES = Math.PI / 180.0;
            cr.new_sub_path ();
            cr.arc (buffer_width - radius, radius, radius, -90 * DEGREES, 0 * DEGREES);
            cr.arc (buffer_width - radius, buffer_height - radius, radius, 0 * DEGREES, 90 * DEGREES);
            cr.arc (radius, buffer_height - radius, radius, 90 * DEGREES, 180 * DEGREES);
            cr.arc (radius, radius, radius, 180 * DEGREES, 270 * DEGREES);
            cr.close_path ();
            cr.set_source_rgb (0, 0, 0);
            cr.clip ();
            cr.paint ();

            cr.save ();
            Cairo.Surface scale_surf = Gdk.cairo_surface_create_from_pixbuf (pixbuf,
                                                                             img_scale,
                                                                             null);
            int width = pixbuf.width / img_scale;
            int height = pixbuf.height / img_scale;
            double window_ratio = (double) buffer_width / buffer_height;
            double bg_ratio = width / height;
            if (window_ratio > bg_ratio) { // Taller wallpaper than monitor
                double scale = (double) buffer_width / width;
                if (scale * height < buffer_height) {
                    draw_scale_wide (buffer_width, width, buffer_height, height, cr, scale_surf);
                } else {
                    draw_scale_tall (buffer_width, width, buffer_height, height, cr, scale_surf);
                }
            } else { // Wider wallpaper than monitor
                double scale = (double) buffer_height / height;
                if (scale * width < buffer_width) {
                    draw_scale_tall (buffer_width, width, buffer_height, height, cr, scale_surf);
                } else {
                    draw_scale_wide (buffer_width, width, buffer_height, height, cr, scale_surf);
                }
            }
            cr.paint ();
            cr.restore ();

            scale_surf.finish ();
            return Gdk.pixbuf_get_from_surface (surface, 0, 0, buffer_width, buffer_height);
        }

        private static void draw_scale_tall (int buffer_width,
                                             int width,
                                             int buffer_height,
                                             int height,
                                             Cairo.Context cr,
                                             Cairo.Surface surface) {
            double scale = (double) buffer_width / width;
            cr.scale (scale, scale);
            cr.set_source_surface (surface,
                                   0, (double) buffer_height / 2 / scale - height / 2);
        }

        private static void draw_scale_wide (int buffer_width,
                                             int width,
                                             int buffer_height,
                                             int height,
                                             Cairo.Context cr,
                                             Cairo.Surface surface) {
            double scale = (double) buffer_height / height;
            cr.scale (scale, scale);
            cr.set_source_surface (
                surface,
                (double) buffer_width / 2 / scale - width / 2, 0);
        }

        public delegate bool FilterFunc (char character);

        public static string filter_string (string body, FilterFunc func) {
            string result = "";
            foreach (char char in (char[]) body.data) {
                if (!func (char)) continue;
                result += char.to_string ();
            }
            return result;
        }
    }
}
