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

        public static string get_style_path () {
            string[] paths = {
                GLib.Environment.get_user_config_dir () + "/swaync/style.css",
            };
            foreach (var path in GLib.Environment.get_system_config_dirs ()) {
                paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                          path, "swaync/style.css");
            }
            paths += "./src/style.css";

            string path = "";
            foreach (string try_path in paths) {
                if (File.new_for_path (try_path).query_exists ()) {
                    path = try_path;
                    break;
                }
            }
            if (path == "") {
                stderr.printf ("COULD NOT FIND CSS FILE! REINSTALL THE PACKAGE!\n");
                Process.exit (1);
            }
            return path;
        }

        public static string get_config_path () {
            string[] paths = {
                GLib.Environment.get_user_config_dir () + "/swaync/config.json",
            };
            foreach (var path in GLib.Environment.get_system_config_dirs ()) {
                paths += Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                          path, "swaync/config.json");
            }
            paths += "./src/config.json";

            string path = "";
            foreach (string try_path in paths) {
                if (File.new_for_path (try_path).query_exists ()) {
                    path = try_path;
                    break;
                }
            }
            if (path == "") {
                stderr.printf ("COULD NOT FIND CONFIG FILE! REINSTALL THE PACKAGE!\n");
                Process.exit (1);
            }
            return path;
        }

        public static ConfigModel parse_config () {
            try {
                Json.Parser parser = new Json.Parser ();
                parser.load_from_file (get_config_path ());
                return ConfigModel (parser.get_root ());
            } catch (Error e) {
                print ("Unable to parse the JSON File: %s\n", e.message);
                Process.exit (1);
            }
        }
    }
}
