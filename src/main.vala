namespace SwayNotificationCenter {
    static SwayncDaemon swaync_daemon;
    static unowned ListModel ? monitors = null;
    static Swaync app;
    static Settings self_settings;

    // Args
    static string ? style_path;
    static string ? config_path;
    // Dev args
    static bool skip_packaged_css = false;
    static string ? custom_packaged_css;

    public class Swaync : Gtk.Application {

        static bool activated = false;

        public signal void config_reload (ConfigModel ? old_config, ConfigModel new_config);

        public Swaync () {
            Object (
                application_id: "org.erikreider.swaync",
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

            hold ();

            unowned Gdk.Display ? display = Gdk.Display.get_default ();
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
                        case "-s":
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
