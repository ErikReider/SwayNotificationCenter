namespace SwayNotificationCenter {
    static SwayncDaemon swaync_daemon;
    static unowned ListModel ?monitors = null;
    static Swaync app;
    static Settings self_settings;

    static HashTable<string, unowned Gdk.PixbufFormat> pixbuf_mime_types;

    // Args
    static string ?style_path;
    static string ?config_path;
    // Dev args
    static bool skip_packaged_css = false;
    static string ?custom_packaged_css;

    private struct EnvironmentVariable {
        string name;

        public EnvironmentVariable (string name) {
            this.name = name;
        }

        public string to_string (string[] envp) {
            return "%s=%s".printf (name, Environ.get_variable (envp, name) ?? "");
        }
    }

    public class Swaync : Gtk.Application {
        static bool activated = false;

        public signal void config_reload (ConfigModel ?old_config, ConfigModel new_config);

        public Swaync () {
            Object (
                application_id : "org.erikreider.swaync",
                flags: ApplicationFlags.DEFAULT_FLAGS
            );

            try {
                register ();
                if (get_is_remote ()) {
                    printerr ("An instance of SwayNotificationCenter is already running!\n");
                    Process.exit (1);
                }
            } catch (Error e) {
                error (e.message);
            }
        }

        public override void activate () {
            if (activated) {
                return;
            }
            activated = true;
            Functions.load_css (style_path);

            pixbuf_mime_types =
                new HashTable<string, unowned Gdk.PixbufFormat> (str_hash, str_equal);
            SList<weak Gdk.PixbufFormat> formats = Gdk.Pixbuf.get_formats ();
            foreach (weak Gdk.PixbufFormat format in formats) {
                foreach (string mime_type in format.get_mime_types ()) {
                    pixbuf_mime_types.set (mime_type, format);
                }
            }

            hold ();

            unowned Gdk.Display ?display = Gdk.Display.get_default ();
            if (display == null) {
                error ("Could not get Display!");
            }
            monitors = display.get_monitors ();

            swaync_daemon = new SwayncDaemon ();
            Bus.own_name (BusType.SESSION, "org.erikreider.swaync.cc",
                          BusNameOwnerFlags.NONE,
                          on_cc_bus_aquired,
                          () => {},
                          () => {
                stderr.printf (
                    "Could not acquire swaync name!...\n");
                Process.exit (1);
            });

            add_window (swaync_daemon.noti_daemon.control_center);
        }

        void on_cc_bus_aquired (DBusConnection conn) {
            try {
                conn.register_object ("/org/erikreider/swaync/cc", swaync_daemon);
            } catch (IOError e) {
                stderr.printf ("Could not register CC service\n");
                Process.exit (1);
            }
        }

        public static int main (string[] args) {
            if (args.length > 0) {
                for (uint i = 1; i < args.length; i++) {
                    string arg = args[i];
                    switch (arg) {
                        case "-s" :
                        case "--style":
                            style_path = args[++i];
                            break;
                        case "--skip-system-css":
                            skip_packaged_css = true;
                            break;
                        case "--custom-system-css":
                            custom_packaged_css = args[++i];
                            break;
                        case "-c":
                        case "--config":
                            config_path = args[++i];
                            break;
                        case "-v":
                        case "--version":
                            stdout.printf ("%s\n", Constants.VERSION);
                            return 0;
                        case "-h":
                        case "--help":
                            print_help (args);
                            return 0;
                        default:
                            print_help (args);
                            return 1;
                    }
                }
            }

            print_startup_info ();

            // Register custom Widgets so that they can be used in .ui template files
            typeof (AnimatedList).ensure ();
            typeof (AnimatedListItem).ensure ();
            typeof (Underlay).ensure ();

            ConfigModel.init (config_path);

            // Fixes custom themes messing with the default/custom CSS styling
            if (ConfigModel.instance.ignore_gtk_theme) {
                Environment.unset_variable ("GTK_THEME");
            }

            Gtk.init ();
            Adw.init ();

            Functions.init ();
            self_settings = new Settings ("org.erikreider.swaync");

            app = new Swaync ();
            return app.run ();
        }

        private static void print_startup_info () {
            print ("Starting SwayNotificationCenter version %s\n", Constants.VERSION);

            // Log distro information
            string info_paths[5] = {
                "/etc/lsb-release",
                "/etc/os-release",
                "/etc/debian_version",
                "/etc/redhat-release",
                "/etc/gentoo-release",
            };
            foreach (unowned string path in info_paths) {
                File ?file = File.new_for_path (path);
                if (file == null) {
                    continue;
                }
                string lines = "";
                try {
                    FileInputStream file_stream = file.read (null);
                    DataInputStream data_stream = new DataInputStream (file_stream);
                    string ?line = null;
                    while ((line = data_stream.read_line (null, null)) != null) {
                        lines += "%s\n".printf (line);
                    }
                } catch (Error e) {
                    continue;
                }
                info ("Contents of %s:\n%s", path, lines);
                break;
            }

            // Log important environment variables
            EnvironmentVariable[] variables = {
                EnvironmentVariable ("XDG_CURRENT_DESKTOP"),
                EnvironmentVariable ("XDG_SESSION_DESKTOP"),
                EnvironmentVariable ("DESKTOP_SESSION"),
                EnvironmentVariable ("XDG_SESSION_TYPE"),
                EnvironmentVariable ("XDG_BACKEND"),
                EnvironmentVariable ("XDG_DATA_HOME"),
                EnvironmentVariable ("XDG_DATA_DIRS"),
                EnvironmentVariable ("SHELL"),
                // From: https://docs.gtk.org/gtk4/running.html
                EnvironmentVariable ("GTK_DEBUG"),
                EnvironmentVariable ("GTK_PATH"),
                EnvironmentVariable ("GTK_IM_MODULE"),
                EnvironmentVariable ("GTK_MEDIA"),
                EnvironmentVariable ("GTK_EXE_PREFIX"),
                EnvironmentVariable ("GTK_DATA_PREFIX"),
                EnvironmentVariable ("GTK_THEME"),
                EnvironmentVariable ("GDK_PIXBUF_MODULE_FILE"),
                EnvironmentVariable ("GDK_DEBUG"),
                EnvironmentVariable ("GSK_DEBUG"),
                EnvironmentVariable ("GDK_BACKEND"),
                EnvironmentVariable ("GDK_DISABLE"),
                EnvironmentVariable ("GDK_GL_DISABLE"),
                EnvironmentVariable ("GDK_VULKAN_DISABLE"),
                EnvironmentVariable ("GDK_WAYLAND_DISABLE"),
                EnvironmentVariable ("GSK_RENDERER"),
                EnvironmentVariable ("GSK_GPU_DISABLE"),
                EnvironmentVariable ("GSK_CACHE_TIMEOUT"),
                EnvironmentVariable ("GTK_CSD"),
                EnvironmentVariable ("GTK_A11Y"),
                EnvironmentVariable ("DESKTOP_STARTUP_ID"),
            };
            string[] envp = Environ.get ();
            string env_variables = "";
            foreach (unowned EnvironmentVariable variable in variables) {
                env_variables += "%s\n".printf (variable.to_string (envp));
            }
            info ("important environment variables:\n%s", env_variables);
        }

        private static void print_help (string[] args) {
            print ("Usage:\n");
            print ("\t %s <OPTION>\n".printf (args[0]));
            print ("Help:\n");
            print ("\t -h, --help \t\t Show help options\n");
            print ("\t -v, --version \t\t Prints version\n");
            print ("Options:\n");
            print ("\t -s, --style \t\t Use a custom Stylesheet file\n");
            print ("\t -c, --config \t\t Use a custom config file\n");
            print ("\t --skip-system-css \t Skip trying to parse the packaged Stylesheet file."
                   + " Useful for CSS debugging\n");
            print ("\t --custom-system-css \t Pick a custom CSS file to use as the \"system\" CSS."
                   + " Useful for CSS debugging\n");
        }
    }
}
