namespace SwayNotificationCenter {
    static NotiDaemon noti_daemon;
    static string ? style_path;
    static string ? config_path;

    public void main (string[] args) {
        Gtk.init (ref args);
        Hdy.init ();

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

        Bus.own_name (BusType.SESSION, "org.freedesktop.Notifications",
                      BusNameOwnerFlags.NONE,
                      on_noti_bus_aquired,
                      () => {},
                      () => {
            stderr.printf (
                "Could not aquire notification name. " +
                "Please close any other notification daemon " +
                "like mako or dunst\n");
            Process.exit (1);
        });

        Functions.load_css (style_path);

        ConfigModel.init (config_path);

        noti_daemon = new NotiDaemon ();

        Gtk.main ();
    }

    void on_noti_bus_aquired (DBusConnection conn) {
        try {
            conn.register_object (
                "/org/freedesktop/Notifications", noti_daemon);
        } catch (IOError e) {
            stderr.printf ("Could not register notification service\n");
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
