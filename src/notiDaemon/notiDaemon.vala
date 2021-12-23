namespace SwayNotificatonCenter {
    [DBus (name = "org.freedesktop.Notifications")]
    public class NotiDaemon : Object {

        private uint32 noti_id = 0;
        private bool dnd = false;

        private CcDaemon ccDaemon;
        private NotiWindow notiWindow;

        public NotiDaemon () {
            this.ccDaemon = new CcDaemon (this);
            Bus.own_name (BusType.SESSION, "org.erikreider.swaync.cc",
                          BusNameOwnerFlags.NONE,
                          on_cc_bus_aquired,
                          () => {},
                          () => stderr.printf (
                              "Could not aquire control center name\n"));

            this.notiWindow = new NotiWindow ();
        }

        private void on_cc_bus_aquired (DBusConnection conn) {
            try {
                conn.register_object ("/org/erikreider/swaync/cc", ccDaemon);
            } catch (IOError e) {
                stderr.printf ("Could not register CC service\n");
                Process.exit (1);
            }
        }

        public void set_noti_window_visibility (bool value)
        throws DBusError, IOError {
            notiWindow.change_visibility (value);
        }

        public bool toggle_dnd () throws DBusError, IOError {
            on_dnd_toggle (dnd = !dnd);
            return dnd;
        }

        public void set_dnd (bool state) throws DBusError, IOError {
            on_dnd_toggle (state);
            dnd = state;
        }

        public bool get_dnd () throws DBusError, IOError {
            return dnd;
        }

        public signal void on_dnd_toggle (bool dnd);

        public void manually_close_notification (uint32 id, bool timeout)
        throws DBusError, IOError {
            notiWindow.close_notification (id);
            if (!timeout) {
                ccDaemon.controlCenter.close_notification (id);
                NotificationClosed (id, ClosedReasons.DISMISSED);
            }
        }

        public void close_all_notifications () throws DBusError, IOError {
            notiWindow.close_all_notifications ();
        }

        /*
         * Specification
         * https://specifications.freedesktop.org/notification-spec/latest/ar01s09.html
         */

        public uint32 Notify (string app_name,
                              uint32 replaces_id,
                              string app_icon,
                              string summary,
                              string body,
                              string[] actions,
                              HashTable<string, Variant> hints,
                              int expire_timeout) throws DBusError, IOError {
            uint32 id = replaces_id;
            if (replaces_id == 0 || replaces_id > noti_id) id = ++noti_id;

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
                notiWindow.close_notification (id);
                ccDaemon.controlCenter.close_notification (id);
            }
            if (!ccDaemon.controlCenter.get_visibility ()) {
                if (param.urgency == UrgencyLevels.CRITICAL ||
                    (!dnd && param.urgency != UrgencyLevels.CRITICAL)) {
                    notiWindow.add_notification (param, this);
                }
            }
            ccDaemon.controlCenter.add_notification (param, this);
            return id;
        }

        public void CloseNotification (uint32 id) throws DBusError, IOError {
            notiWindow.close_notification (id);
            ccDaemon.controlCenter.close_notification (id);
            NotificationClosed (id, ClosedReasons.CLOSED_BY_CLOSENOTIFICATION);
        }

        public string[] GetCapabilities () throws DBusError, IOError {
            string[] capabilities = {
                "actions",
                "body",
                "body-markup",
                "body-images",
                "body-hyperlinks",
                "persistence",
            };
            return capabilities;
        }

        public void GetServerInformation (out string name,
                                          out string vendor,
                                          out string version,
                                          out string spec_version)
        throws DBusError, IOError {
            name = "SwayNotificationCenter";
            vendor = "ErikReider";
            version = "0.3";
            spec_version = "1.2";
        }

        public signal void NotificationClosed (uint32 id, uint32 reason);

        public signal void ActionInvoked (uint32 id, string action_key);
    }
}
