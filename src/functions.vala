namespace SwayNotificationCenter {
    public class Functions {
        const Gsk.ScalingFilter SCALING_FILTER = Gsk.ScalingFilter.NEAREST;

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

        public static string uri_to_path (owned string uri) {
            uri = uri.strip ();
            const string URI_PREFIX = "file://";
            bool is_uri = (uri.length >= URI_PREFIX.length
                           && uri.slice (0, URI_PREFIX.length) == URI_PREFIX);
            if (is_uri) {
                // Try as a URI (file:// is the only URI schema supported right now)
                uri = uri.slice (URI_PREFIX.length, uri.length);
            }
            return uri;
        }

        public static void set_image_uri (owned string uri,
                                          Gtk.Image img,
                                          bool file_exists,
                                          bool is_theme_icon = false) {
            const string URI_PREFIX = "file://";
            bool is_uri = (uri.length >= URI_PREFIX.length
                           && uri.slice (0, URI_PREFIX.length) == URI_PREFIX);
            if (!is_theme_icon && (is_uri || file_exists)) {
                // Try as a URI (file:// is the only URI schema supported right now)
                try {
                    if (is_uri) uri = uri.slice (URI_PREFIX.length, uri.length);

                    Gdk.Texture texture = Gdk.Texture.from_filename (Uri.unescape_string (uri));
                    img.set_from_paintable (texture);
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
            }

            // Try as icon name
            if (img.storage_type == Gtk.ImageType.EMPTY) {
                unowned Gdk.Display display = Gdk.Display.get_default ();
                unowned Gtk.IconTheme icon_theme = Gtk.IconTheme.get_for_display (display);
                if (icon_theme.has_icon (uri)) {
                    img.set_from_icon_name (uri);
                }
            }
        }

        public static void set_image_data (ImageData data,
                                           Gtk.Image img) {
            Gdk.MemoryFormat format = Gdk.MemoryFormat.R8G8B8;
            if (data.has_alpha) {
                format = Gdk.MemoryFormat.R8G8B8A8;
            }
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
            system_css = File.new_for_path (system_css).get_path () ?? system_css;
            if (custom_packaged_css != null) {
                system_css = custom_packaged_css;
            }
            if (!skip_packaged_css) {
                message ("Loading CSS: \"%s\"", system_css);
                system_css_provider.load_from_path (system_css);
                Gtk.StyleContext.add_provider_for_display (
                    Gdk.Display.get_default (),
                    system_css_provider,
                    css_priority);
            } else {
                message ("Skipping system CSS: \"%s\"", system_css);
            }

            // Load user CSS
            string user_css = get_style_path (style_path);
            user_css = File.new_for_path (user_css).get_path () ?? user_css;
            message ("Loading CSS: \"%s\"", user_css);
            user_css_provider.load_from_path (user_css);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                user_css_provider,
                css_priority);

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

        /** Gets the base type of a type if it's derivited */
        public static Type get_base_type (Type type) {
            if (type.is_derived ()) {
                while (type.is_derived ()) {
                    type = type.parent ();
                }
            }
            return type;
        }

        /** Scales the Texture to fit the given dimensions */
        public static void scale_texture (Gdk.Texture texture,
                                          int buffer_width,
                                          int buffer_height,
                                          int img_scale,
                                          Gtk.Snapshot snapshot) {
            int width = texture.width / img_scale;
            int height = texture.height / img_scale;
            double window_ratio = (double) buffer_width / buffer_height;
            double bg_ratio = width / height;
            snapshot.save ();
            if (window_ratio > bg_ratio) { // Taller wallpaper than monitor
                double scale = (double) buffer_width / width;
                if (scale * height < buffer_height) {
                    draw_scale_wide (buffer_width, width, buffer_height, height, snapshot, texture);
                } else {
                    draw_scale_tall (buffer_width, width, buffer_height, height, snapshot, texture);
                }
            } else { // Wider wallpaper than monitor
                double scale = (double) buffer_height / height;
                if (scale * width < buffer_width) {
                    draw_scale_tall (buffer_width, width, buffer_height, height, snapshot, texture);
                } else {
                    draw_scale_wide (buffer_width, width, buffer_height, height, snapshot, texture);
                }
            }

            snapshot.restore ();
        }

        private static void draw_scale_tall (int buffer_width,
                                             int width,
                                             int buffer_height,
                                             int height,
                                             Gtk.Snapshot snapshot,
                                             Gdk.Texture texture) {
            float scale = (float) buffer_width / width;
            snapshot.scale (scale, scale);
            float x = 0;
            float y = (float) (buffer_height / 2 / scale - height / 2);
            snapshot.append_scaled_texture (texture,
                                            SCALING_FILTER,
                                            { { x, y }, { width, height } });
        }

        private static void draw_scale_wide (int buffer_width,
                                             int width,
                                             int buffer_height,
                                             int height,
                                             Gtk.Snapshot snapshot,
                                             Gdk.Texture texture) {
            float scale = (float) buffer_height / height;
            snapshot.scale (scale, scale);
            float x = (float) (buffer_width / 2 / scale - width / 2);
            float y = 0;
            snapshot.append_scaled_texture (texture,
                                            SCALING_FILTER,
                                            { { x, y }, { width, height } });
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

                string[] argvp;
                Shell.parse_argv ("/bin/sh -c \"%s\"".printf (cmd), out argvp);

                if (argvp[0].has_prefix ("~"))
                    argvp[0] = Environment.get_home_dir () + argvp[0].substring (1);

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
                        if (channel.read_line (out res, null, null) == IOStatus.NORMAL) {
                            debug ("Exec output:\n%s", res);
                        } else {
                            res = "";
                        }
                        return true;
                    } catch (IOChannelError e) {
                        warning ("stdout: IOChannelError: %s", e.message);
                        return false;
                    } catch (ConvertError e) {
                        warning ("stdout: ConvertError: %s", e.message);
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
                // Waits until `execute_command.callback()` is called above
                yield;
                msg = res;
                return end_status == 0;
            } catch (Error e) {
                warning ("Execute Command Error: %s", e.message);
                msg = e.message;
                return false;
            }
        }

        public static unowned Wl.Display get_wl_display () {
            unowned var display = Gdk.Display.get_default ();
            if (display is Gdk.Wayland.Display) {
                return ((Gdk.Wayland.Display) display).get_wl_display ();
            }
            error ("Only supports Wayland!");
        }

        public static Wl.Surface * get_wl_surface (Gdk.Surface surface) {
            if (surface is Gdk.Wayland.Surface) {
                return ((Gdk.Wayland.Surface) surface).get_wl_surface ();
            }
            error ("Only supports Wayland!");
        }

        public static double lerp (double a, double b, double t) {
            return a * (1.0 - t) + b * t;
        }

        public static unowned Gdk.Monitor ? try_get_monitor (string name) {
            if (name == null || name.length == 0) {
                return null;
            }

            for (int i = 0; i < monitors.get_n_items (); i++) {
                Object ? obj = monitors.get_item (i);
                if (obj == null || !(obj is Gdk.Monitor)) continue;
                unowned Gdk.Monitor monitor = (Gdk.Monitor) obj;

                if (monitor.connector == name) {
                    return monitor;
                }

                // Try matching a string consisting of the manufacturer + model + serial number.
                // Just like Sway does (sway-output(5) man page)
                string id = "%s %s %s".printf (monitor.manufacturer,
                                               monitor.model,
                                               monitor.description);
                if (id == name) {
                    return monitor;
                }
            }

            return null;
        }
    }
}
