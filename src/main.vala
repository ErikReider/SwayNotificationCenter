namespace SwayNotificationCenter {
    static SwayncDaemon swaync_daemon;
    static string ? style_path;
    static string ? config_path;

    static Settings self_settings;

    public void main (string[] args) {
        Gtk.init (ref args);
        Hdy.init ();
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
                    case "-c":
                    case "--config":
                        config_path = args[++i];
                        break;
                    case "-v":
                    case "--version":
                        stdout.printf ("%s\n", Constants.VERSION);
                        return;
                    case "-h":
                    case "--help":
                    default:
                        print_help (args);
                        return;
                }
            }
        }

        Functions.load_css (style_path);
        ConfigModel.init (config_path);

        swaync_daemon = new SwayncDaemon ();
        Bus.own_name (BusType.SESSION, "org.erikreider.swaync.cc",
                      BusNameOwnerFlags.NONE,
                      on_cc_bus_aquired,
                      () => {},
                      () => {
            stderr.printf (
                "Could not aquire swaync name!...\n");
            Process.exit (1);
        });

        Gtk.main ();
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
    }
}
