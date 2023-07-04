namespace SwayNotificationCenter {
    static SwayncDaemon swaync_daemon;
    // Args
    static string ? style_path;
    static string ? config_path;
    // Dev args
    static bool no_base_css = false;

    static uint layer_shell_protocol_version = 3;

    static Settings self_settings;

    public void main (string[] args) {
        if (args.length > 0) {
            for (uint i = 1; i < args.length; i++) {
                string arg = args[i];
                switch (arg) {
                    case "-s":
                    case "--style":
                        style_path = args[++i];
                        break;
                    case "-D":
                        string dev_arg = args[++i];
                        switch (dev_arg) {
                            case "no-base-css":
                                no_base_css = true;
                                break;
                            default:
                                break;
                        }
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

        Adw.init ();
        Gtk.init ();
        Functions.init ();

        var app = new Gtk.Application ("org.erikreider.swaync", ApplicationFlags.DEFAULT_FLAGS);

        app.activate.connect (() => {
            self_settings = new Settings ("org.erikreider.swaync");

            ConfigModel.init (config_path);
            Functions.load_css (style_path);

            if (ConfigModel.instance.layer_shell) {
                layer_shell_protocol_version = GtkLayerShell.get_protocol_version ();
            }

            swaync_daemon = new SwayncDaemon ();
            // TODO: Remove ".cc"/"/cc" for all servers and client
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

        // Gtk.init ();

        // new MainLoop ().run ();
        app.run (null);
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
