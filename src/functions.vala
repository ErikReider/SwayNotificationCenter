namespace SwayNotificationCenter {
    public class Functions {
        private static Gtk.CssProvider system_css_provider;
        private static Gtk.CssProvider user_css_provider;

        private Functions () {}

        public static void init () {
            system_css_provider = new Gtk.CssProvider ();
            user_css_provider = new Gtk.CssProvider ();

            // Init resources
            var theme = Gtk.IconTheme.get_default ();
            theme.add_resource_path ("/org/erikreider/swaync/icons");
        }

        public static void set_image_uri (owned string uri,
                                          Gtk.Image img,
                                          int icon_size,
                                          int radius,
                                          bool file_exists,
                                          bool is_theme_icon = false) {
            const string URI_PREFIX = "file://";
            bool is_uri = (uri.length >= URI_PREFIX.length
                           && uri.slice (0, URI_PREFIX.length) == URI_PREFIX);
            if (!is_theme_icon && (is_uri || file_exists)) {
                // Try as a URI (file:// is the only URI schema supported right now)
                try {
                    if (is_uri) uri = uri.slice (URI_PREFIX.length, uri.length);

                    var pixbuf = new Gdk.Pixbuf.from_file_at_scale (
                        Uri.unescape_string (uri),
                        icon_size * img.scale_factor,
                        icon_size * img.scale_factor,
                        true);
                    // Scale and round the image. Scales to fit the size
                    var surface = scale_round_pixbuf (pixbuf,
                                                      icon_size,
                                                      icon_size,
                                                      img.scale_factor,
                                                      radius);
                    img.set_from_surface (surface);
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
            }

            // Try as icon name
            if (img.storage_type == Gtk.ImageType.EMPTY) {
                img.set_from_icon_name (uri, Gtk.IconSize.INVALID);
            }
        }

        public static void set_image_data (ImageData data,
                                           Gtk.Image img,
                                           int icon_size,
                                           int radius) {
            // Rebuild and scale the image
            var pixbuf = new Gdk.Pixbuf.with_unowned_data (data.data,
                                                           Gdk.Colorspace.RGB,
                                                           data.has_alpha,
                                                           data.bits_per_sample,
                                                           data.width,
                                                           data.height,
                                                           data.rowstride,
                                                           null);

            var surface = scale_round_pixbuf (pixbuf,
                                              icon_size,
                                              icon_size,
                                              img.scale_factor,
                                              radius);
            img.set_from_surface (surface);
        }

        /** Load the package provided CSS file as a base.
         * Without this, an empty user CSS file would result in widgets
         * with default GTK style properties
         */
        public static bool load_css (string ? style_path) {
            int css_priority = ConfigModel.instance.cssPriority.get_priority ();

            // Load packaged CSS as backup
            string system_css = get_style_path (null, true);
            system_css = File.new_for_path (system_css).get_path () ?? system_css;
            message ("Loading CSS: \"%s\"", system_css);
            try {
                system_css_provider.load_from_path (system_css);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (),
                    system_css_provider,
                    css_priority);
            } catch (Error e) {
                critical ("Load packaged CSS Error (\"%s\"):\n\t%s\n", system_css, e.message);
            }

            // Load user CSS
            string user_css = get_style_path (style_path);
            user_css = File.new_for_path (user_css).get_path () ?? user_css;
            message ("Loading CSS: \"%s\"", user_css);
            try {
                user_css_provider.load_from_path (user_css);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (),
                    user_css_provider,
                    css_priority);
            } catch (Error e) {
                critical ("Load user CSS Error (\"%s\"):\n\t%s\n", user_css, e.message);
                return false;
            }

            return true;
        }

        public static string get_style_path (owned string ? custom_path,
                                             bool only_system = false) {
            string[] paths = {};
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
            // Fallback location. Specified in postinstall.py. Mostly for Debian
            paths += "/usr/local/etc/xdg/swaync/style.css";

            info ("Looking for CSS file in these directories:\n\t- %s",
                  string.joinv ("\n\t- ", paths));

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
            string[] paths = {};
            if (custom_path != null && (custom_path = custom_path.strip ()).length > 0) {
                // Replaces the home directory relative path with a absolute path
                if (custom_path.get (0) == '~') {
                    custom_path = Environment.get_home_dir () + custom_path[1:];
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
            // Fallback location. Specified in postinstall.py. Mostly for Debian
            paths += "/usr/local/etc/xdg/swaync/config.json";

            info ("Looking for config file in these directories:\n\t- %s",
                  string.joinv ("\n\t- ", paths));

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

        /** Roundes the Cairo Surface to the given radii */
        public static Cairo.Surface round_surface (Cairo.Surface base_surf,
                                                   int buffer_width,
                                                   int buffer_height,
                                                   int img_scale,
                                                   int radius) {
            // Limit radii size
            radius = int.min (radius, int.min (buffer_width / 2, buffer_height / 2));

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
            cr.set_source_rgba (0, 0, 0, 0);
            cr.clip ();
            cr.paint ();

            cr.save ();
            cr.set_source_surface (base_surf, 0, 0);
            cr.paint ();
            cr.restore ();

            return surface;
        }

        /** Scales the pixbuf to fit the given dimensions */
        public static Cairo.Surface scale_pixbuf (Gdk.Pixbuf pixbuf,
                                                  int buffer_width,
                                                  int buffer_height,
                                                  int img_scale) {

            Cairo.Surface surface = new Cairo.ImageSurface (Cairo.Format.ARGB32,
                                                            buffer_width,
                                                            buffer_height);
            var cr = new Cairo.Context (surface);

            cr.save ();
            Cairo.Surface base_surf = Gdk.cairo_surface_create_from_pixbuf (pixbuf,
                                                                             img_scale,
                                                                             null);
            int width = pixbuf.width / img_scale;
            int height = pixbuf.height / img_scale;
            double window_ratio = (double) buffer_width / buffer_height;
            double bg_ratio = width / height;
            if (window_ratio > bg_ratio) { // Taller wallpaper than monitor
                double scale = (double) buffer_width / width;
                if (scale * height < buffer_height) {
                    draw_scale_wide (buffer_width, width, buffer_height, height, cr, base_surf);
                } else {
                    draw_scale_tall (buffer_width, width, buffer_height, height, cr, base_surf);
                }
            } else { // Wider wallpaper than monitor
                double scale = (double) buffer_height / height;
                if (scale * width < buffer_width) {
                    draw_scale_tall (buffer_width, width, buffer_height, height, cr, base_surf);
                } else {
                    draw_scale_wide (buffer_width, width, buffer_height, height, cr, base_surf);
                }
            }
            cr.paint ();
            cr.restore ();

            base_surf.finish ();
            return surface;
        }

        /** Scales the pixbuf to fit the given dimensions */
        public static Cairo.Surface scale_round_pixbuf (Gdk.Pixbuf pixbuf,
                                                        int buffer_width,
                                                        int buffer_height,
                                                        int img_scale,
                                                        int radius) {
            var surface = Functions.scale_pixbuf (pixbuf,
                                                  buffer_width,
                                                  buffer_height,
                                                  img_scale);
            surface = Functions.round_surface (surface,
                                               buffer_width,
                                               buffer_height,
                                               img_scale,
                                               radius);
            return surface;
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

        public static async bool execute_command (string cmd, string[] env_additions = {}, out string msg) {
            msg = "";
            try {
                string[] spawn_env = Environ.get ();
                // Export env variables
                foreach (string additions in env_additions) {
                    spawn_env += additions;
                }

                string[] argvp = {};
                Shell.parse_argv (cmd, out argvp);

                Pid child_pid;
                int std_output;
                Process.spawn_async_with_pipes (
                    "/",
                    argvp,
                    spawn_env,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null,
                    out child_pid,
                    null,
                    out std_output,
                    null);

                // stdout:
                string res = "";
                IOChannel output = new IOChannel.unix_new (std_output);
                output.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
                    if (condition == IOCondition.HUP) {
                        return false;
                    }
                    try {
                        channel.read_line (out res, null, null);
                        return true;
                    } catch (IOChannelError e) {
                        stderr.printf ("stdout: IOChannelError: %s\n", e.message);
                        return false;
                    } catch (ConvertError e) {
                        stderr.printf ("stdout: ConvertError: %s\n", e.message);
                        return false;
                    }
                });

                // Close the child when the spawned process is idling
                int end_status = 0;
                ChildWatch.add (child_pid, (pid, status) => {
                    Process.close_pid (pid);
                    GLib.FileUtils.close (std_output);
                    end_status = status;
                    execute_command.callback ();
                });
                // Waits until `run_script.callback()` is called above
                yield;
                msg = res;
                return end_status == 0;
            } catch (Error e) {
                stderr.printf ("Run_Script Error: %s\n", e.message);
                msg = e.message;
                return false;
            }
        }
    }
}
