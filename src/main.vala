namespace SwayNotificatonCenter {

    public struct NotifyParams {
        public uint32 applied_id { get; set; }
        public string app_name { get; set; }
        public uint32 replaces_id { get; set; }
        public string app_icon { get; set; }
        public string summary { get; set; }
        public string body { get; set; }
        public string[] actions { get; set; }
        public HashTable<string, Variant> hints { get; set; }
        public int expire_timeout { get; set; }

        public NotifyParams (uint32 applied_id,
                             string app_name,
                             uint32 replaces_id,
                             string app_icon,
                             string summary,
                             string body,
                             string[] actions,
                             HashTable<string, Variant> hints,
                             int expire_timeout) {
            this.applied_id = applied_id;
            this.app_name = app_name;
            this.replaces_id = replaces_id;
            this.app_icon = app_icon;
            this.summary = summary;
            this.body = body;
            this.actions = actions;
            this.hints = hints;
            this.expire_timeout = expire_timeout;
        }

        public void printParams () {
            // print (applied_id.to_string () + "\n");
            // print (app_name + "\n");
            // print (replaces_id.to_string () + "\n");
            // print (app_icon + "\n");
            // print (summary + "\n");
            // print (body + "\n");
            print ("----Actions----\n");
            foreach (var action in actions) {
                print (action + "\n");
            }
            print ("----END----\n");

            // foreach (var hint in hints.get_values ()) {
            // hint.print (false);
            // }
            print ("----Hints----\n");
            foreach (var key in hints.get_keys ()) {
                print (key + "\n");
            }
            print ("----END----\n");
            // print (expire_timeout.to_string () + "\n");
        }
    }

    [DBus (name = "org.freedesktop.Notifications")]
    public class NotiDaemon : Object {

        private uint32 noti_id = 1;

        public NotiWindow notiWin;
        private DBusInit dbusInit;

        public NotiDaemon (DBusInit dbusInit) {
            this.dbusInit = dbusInit;
            this.notiWin = new NotiWindow ();
        }

        public void set_noti_window_visibility (bool value)
        throws DBusError, IOError {
            notiWin.set_visible (value);
        }

        public uint32 Notify (string app_name,
                              uint32 replaces_id,
                              string app_icon,
                              string summary,
                              string body,
                              string[] actions,
                              HashTable<string, Variant> hints,
                              int expire_timeout)
        throws DBusError, IOError {
            uint32 id = replaces_id == 0 ? ++noti_id : replaces_id;

            var param = NotifyParams (
                id,
                app_name,
                replaces_id,
                app_icon,
                summary,
                body,
                actions,
                hints,
                expire_timeout);

            if (id == replaces_id) {
                notiWin.close_notification (id);
                dbusInit.ccDaemon.close_notification (id);
            }
            if (!dbusInit.ccDaemon.get_visibility ()) {
                notiWin.add_notification (param, this);
            }
            dbusInit.ccDaemon.add_notification (param);
            return id;
        }

        public void click_close_notification (uint32 id) throws DBusError, IOError {
            notiWin.close_notification (id);
            dbusInit.ccDaemon.close_notification (id);
        }

        // Only remove the popup without removing the it from the panel
        public void CloseNotification (uint32 id) throws DBusError, IOError {
            notiWin.close_notification (id);
        }

        public void GetServerInformation (out string name,
                                          out string vendor,
                                          out string version,
                                          out string spec_version)
        throws DBusError, IOError {
            name = "SwayNotificationCenter";
            vendor = "ErikReider";
            version = "0.1";
            spec_version = "1.0";
        }

        public signal void NotificationClosed (uint32 id, uint32 reason);

        public signal void ActionInvoked (uint32 id, uint32 reason);
    }

    public class DBusInit {

        public NotiDaemon notiDaemon;
        public CcDaemon ccDaemon;

        public DBusInit () {
            this.notiDaemon = new NotiDaemon (this);
            this.ccDaemon = new CcDaemon (this);

            Bus.own_name (BusType.SESSION, "org.freedesktop.Notifications",
                          BusNameOwnerFlags.NONE,
                          on_noti_bus_aquired,
                          () => {},
                          () => stderr.printf ("Could not aquire notification name\n"));


            Bus.own_name (BusType.SESSION, "org.erikreider.swaync.cc",
                          BusNameOwnerFlags.NONE,
                          on_cc_bus_aquired,
                          () => {},
                          () => stderr.printf ("Could not aquire CC name\n"));
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
        Hdy.init ();

        try {
            Gtk.CssProvider css_provider = new Gtk.CssProvider ();
            css_provider.load_from_path ("src/style.css");
            Gtk.StyleContext.
             add_provider_for_screen (
                Gdk.Screen.get_default (),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_USER);
        } catch (Error e) {
            print ("Error: %s\n", e.message);
        }

        new DBusInit ();

        Gtk.main ();
    }
}
