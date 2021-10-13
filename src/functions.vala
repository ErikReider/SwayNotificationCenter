namespace SwayNotificatonCenter {
    public class Functions {
        public static void set_image_path (owned string path,
                                           Gtk.Image img,
                                           bool file_exists) {
            if (path.slice (0, 7) == "file://" || file_exists) {
                try {
                    if (!file_exists) path = path.slice (7, path.length);

                    var pixbuf = new Gdk.Pixbuf.from_file_at_size (path, 64, 64);
                    img.set_from_pixbuf (pixbuf);
                    return;
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
            }
            img.set_from_icon_name ("image-missing", Gtk.IconSize.DIALOG);
        }

        public static void set_image_data (Image_Data data, Gtk.Image img) {
            // Rebuild and scale the image
            var pixbuf = new Gdk.Pixbuf.with_unowned_data (data.data,
                                                           Gdk.Colorspace.RGB,
                                                           data.has_alpha,
                                                           data.bits_per_sample,
                                                           data.width,
                                                           data.height,
                                                           data.rowstride,
                                                           null);
            var scaled_pixbuf = pixbuf.scale_simple (64, 64,
                                                     Gdk.InterpType.BILINEAR);
            img.set_from_pixbuf (scaled_pixbuf);
        }

        public static string get_style_path (string custon_path) {
            string[] paths = {};
            if (custon_path.length > 0) paths += custon_path;
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

        public static string get_config_path (string custom_path = "") {
            string[] paths = {};
            if (custom_path.length > 0) paths += custom_path;
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
                // Replace "~/" with $HOME
                if (img.index_of ("~/", 0) == 0) {
                    img = GLib.Environment.get_home_dir () +
                          img.slice (1, img.length);
                }
                return img;
            }
            return "";
        }
    }
}
