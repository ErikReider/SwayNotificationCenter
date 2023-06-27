namespace SwayNotificationCenter {
    public class Functions {
        private static Gtk.CssProvider system_css_provider;
        private static Gtk.CssProvider user_css_provider;

        private Functions () {}

        public static void init () {
            system_css_provider = new Gtk.CssProvider ();
            user_css_provider = new Gtk.CssProvider ();

            // Init resources
            var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            theme.add_resource_path ("/org/erikreider/swaync/icons");
        }

        public static void set_image_path (owned string path,
                                           Gtk.Image img,
                                           bool file_exists) {
            // img.set_pixel_size (Notification.icon_size);
            if ((path.length > 6 && path.slice (0, 7) == "file://") || file_exists) {
                // Try as a URI (file:// is the only URI schema supported right now)
                try {
                    if (!file_exists) path = path.slice (7, path.length);
                    Gdk.Texture texture = Gdk.Texture.from_filename (path);
                    img.set_from_paintable (texture);
                    return;
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
            } else if (Gtk.IconTheme.get_for_display (img.get_display ()).has_icon (path)) {
                // Try as a freedesktop.org-compliant icon theme
                img.set_from_icon_name (path);
            } else {
                img.set_from_icon_name ("image-missing");
            }
        }

        public static void set_image_data (ImageData data, Gtk.Image img) {
            Gdk.MemoryFormat format = Gdk.MemoryFormat.R8G8B8;
            if (data.has_alpha) {
                format = Gdk.MemoryFormat.R8G8B8A8;
            }
            // TODO: Handle images with more channels?
            var texture = new Gdk.MemoryTexture (data.width, data.height,
                                                 format,
                                                 new Bytes.static (data.data),
                                                 data.rowstride);
            img.set_from_paintable (texture);
        }

        /** Load the package provided CSS file as a base.
         * Without this, an empty user CSS file would result in widgets
         * with default GTK style properties
         */
        public static bool load_css (string ? style_path) {
            int css_priority = ConfigModel.instance.cssPriority.get_priority ();

            // Load packaged CSS as backup
            string system_css = get_style_path (null, true);
            system_css_provider.load_from_path (system_css);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                system_css_provider,
                css_priority);

            // Load user CSS
            string user_css = get_style_path (style_path);
            user_css_provider.load_from_path (user_css);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                user_css_provider,
                css_priority);
            return true;
        }

        public static string clean_path (owned string path) {
            // Replaces the home directory relative path with a absolute path
            if (path.get (0) == '~') {
                path = Environment.get_home_dir () + path[1 :];
            }
            return path;
        }

        public static string get_style_path (owned string ? custom_path,
                                             bool only_system = false) {
            string[] paths = {
                // Fallback location. Specified in postinstall.py
                "/usr/etc/xdg/swaync/style.css",
                "/usr/local/etc/xdg/swaync/style.css"
            };
            if (custom_path != null && custom_path.length > 0) {
                // Replaces the home directory relative path with a absolute path
                paths += clean_path (custom_path);
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
            if (custom_path != null && (custom_path = custom_path.strip ()).length > 0) {
                // Replaces the home directory relative path with a absolute path
                if (custom_path.get (0) == '~') {
                    custom_path = Environment.get_home_dir () + custom_path[1 :];
                }

                if (File.new_for_path (custom_path).query_exists ()) {
                    paths += custom_path;
                } else {
                    critical ("Custom config file \"%s\" not found, skipping...", custom_path);
                }
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

        /** Scales and applies a scaled texture to fit the given dimensions */
        public static void snapshot_apply_scaled_texture (Gtk.Snapshot snap,
                                                          Gdk.Texture texture,
                                                          float buffer_width,
                                                          float buffer_height,
                                                          float img_scale) {
            float width = texture.width / img_scale;
            float height = texture.height / img_scale;
            float window_ratio = buffer_width / buffer_height;
            float bg_ratio = width / height;
            snap.save ();
            if (window_ratio > bg_ratio) { // Taller wallpaper than monitor
                float scale = buffer_width / width;
                if (scale * height < buffer_height) {
                    translate_wide (buffer_width, width, buffer_height, height, snap);
                } else {
                    translate_tall (buffer_width, width, buffer_height, height, snap);
                }
            } else { // Wider wallpaper than monitor
                float scale = buffer_height / height;
                if (scale * width < buffer_width) {
                    translate_tall (buffer_width, width, buffer_height, height, snap);
                } else {
                    translate_wide (buffer_width, width, buffer_height, height, snap);
                }
            }
            snap.append_scaled_texture (
                texture,
                Gsk.ScalingFilter.TRILINEAR,
                Graphene.Rect ().init (0, 0, width, height)
            );
            snap.restore ();
        }

        private static void translate_tall (float buffer_width,
                                            float width,
                                            float buffer_height,
                                            float height,
                                            Gtk.Snapshot snap) {
            float scale = buffer_width / width;
            snap.scale (scale, scale);
            snap.translate (Graphene.Point ().init (
                    0, buffer_height / 2 / scale - height / 2));
        }

        private static void translate_wide (float buffer_width,
                                            float width,
                                            float buffer_height,
                                            float height,
                                            Gtk.Snapshot snap) {
            float scale = (float) buffer_height / height;
            snap.scale (scale, scale);
            snap.translate (Graphene.Point ().init (
                    (float) buffer_width / 2 / scale - width / 2, 0));
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
