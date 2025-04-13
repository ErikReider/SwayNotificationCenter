namespace SwayNotificationCenter {
    static SwayncDaemon swaync_daemon;
    // Args
    static string ? style_path;
    static string ? config_path;
    // Dev args
    static bool skip_packaged_css = false;

    static Settings self_settings;

    static bool activated = false;

    public int main (string[] args) {
        Gtk.init ();
        Adw.init ();
        Functions.init ();

        self_settings = new Settings ("org.erikreider.swaync");

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

        var app = new Gtk.Application ("org.erikreider.swaync",
                                       ApplicationFlags.DEFAULT_FLAGS);
        app.activate.connect (() => {
            if (activated) {
                return;
            }
            activated = true;
            ConfigModel.init (config_path);
            Functions.load_css (style_path);

            app.hold ();

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

            app.add_window (swaync_daemon.noti_daemon.control_center);
        });

        return app.run ();
    }

    void on_cc_bus_aquired (DBusConnection conn) {
        try {
            conn.register_object ("/org/erikreider/swaync/cc", swaync_daemon);
        } catch (IOError e) {
            stderr.printf ("Could not register CC service\n");
            Process.exit (1);
        }
    }

    private void print_help (string[] args) {
        print ("Usage:\n");
        print ("\t %s <OPTION>\n".printf (args[0]));
        print ("Help:\n");
        print ("\t -h, --help \t\t Show help options\n");
        print ("\t -v, --version \t\t Prints version\n");
        print ("Options:\n");
        print ("\t -s, --style \t\t Use a custom Stylesheet file\n");
        print ("\t -c, --config \t\t Use a custom config file\n");
        print ("\t --skip-system-css \t Skip trying to parse the packaged Stylesheet file. Useful for CSS debugging\n");
    }
}
