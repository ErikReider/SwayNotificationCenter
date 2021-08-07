namespace SwayNotificatonCenter {
    public class DBusInit {

        public NotiDaemon notiDaemon;
        public CcDaemon ccDaemon;

        public ConfigModel configModel;

        public DBusInit () {
            configModel = Functions.parse_config ();

            this.notiDaemon = new NotiDaemon (this);
            this.ccDaemon = new CcDaemon (this);


            Bus.own_name (BusType.SESSION, "org.freedesktop.Notifications",
                          BusNameOwnerFlags.NONE,
                          on_noti_bus_aquired,
                          () => {},
                          () => stderr.printf ("Could not aquire notification name. Please close any other notification daemon like mako or dunst\n"));


            Bus.own_name (BusType.SESSION, "org.erikreider.swaync.cc",
                          BusNameOwnerFlags.NONE,
                          on_cc_bus_aquired,
                          () => {},
                          () => stderr.printf ("Could not aquire control center name\n"));
        }

        void on_noti_bus_aquired (DBusConnection conn) {
            try {
                conn.register_object ("/org/freedesktop/Notifications", notiDaemon);
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

    public void main (string[] args) {
        Gtk.init (ref args);

        try {
            Gtk.CssProvider css_provider = new Gtk.CssProvider ();
            css_provider.load_from_path (Functions.get_style_path ());
            Gtk.StyleContext.add_provider_for_screen (
                Gdk.Screen.get_default (),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (Error e) {
            print ("Error: %s\n", e.message);
        }

        new DBusInit ();

        Gtk.main ();
    }
}
