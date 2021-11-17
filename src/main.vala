namespace SwayNotificatonCenter {
    public class DBusInit {

        public NotiDaemon notiDaemon;
        public CcDaemon ccDaemon;

        public string style_path;
        public string config_path;

        public DBusInit (string style_path, string config_path) {
            this.style_path = style_path;
            this.config_path = config_path;
            this.notiDaemon = new NotiDaemon (this);
            this.ccDaemon = new CcDaemon (this);


            Bus.own_name (BusType.SESSION, "org.freedesktop.Notifications",
                          BusNameOwnerFlags.NONE,
                          on_noti_bus_aquired,
                          () => {},
                          () => stderr.printf (
                              "Could not aquire notification name. " +
                              "Please close any other notification daemon " +
                              "like mako or dunst\n"));


            Bus.own_name (BusType.SESSION, "org.erikreider.swaync.cc",
                          BusNameOwnerFlags.NONE,
                          on_cc_bus_aquired,
                          () => {},
                          () => stderr.printf (
                              "Could not aquire control center name\n"));
        }

        void on_noti_bus_aquired (DBusConnection conn) {
            try {
                conn.register_object (
                    "/org/freedesktop/Notifications", notiDaemon);
            } catch (IOError e) {
                stderr.printf ("Could not register notification service\n");
            }
        }

        void on_cc_bus_aquired (DBusConnection conn) {
            try {
                conn.register_object ("/org/erikreider/swaync/cc", ccDaemon);
            } catch (IOError e) {
                stderr.printf ("Could not register CC service\n");
            }
        }
    }

    private void print_help (string[] args) {
        print (@"Usage:\n");
        print (@"\t $(args[0]) <OPTION>\n");
        print (@"Help:\n");
        print (@"\t -h, --help \t\t Show help options\n");
        print (@"Options:\n");
        print (@"\t -s, --style \t\t Use a custom Stylesheet file\n");
        print (@"\t -c, --config \t\t Use a custom config file\n");
    }

    public void main (string[] args) {
        Gtk.init (ref args);
        Hdy.init ();

        string style_path = "";
        string config_path = "";

        if (args.length > 0) {
            if ("-h" in args || "--help" in args) {
                print_help (args);
                return;
            }
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
                    default:
                        print_help (args);
                        return;
                }
            }
        }

        Functions.load_css (style_path);

        ConfigModel.init (config_path);

        new DBusInit (style_path, config_path);

        Gtk.main ();
    }
}
