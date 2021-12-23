namespace SwayNotificatonCenter {
    [DBus (name = "org.erikreider.swaync.cc")]
    public class CcDaemon : Object {
        public ControlCenter controlCenter;
        public NotiDaemon notiDaemon;

        public CcDaemon (NotiDaemon notiDaemon) {
            this.notiDaemon = notiDaemon;
            this.controlCenter = new ControlCenter (this);

            notiDaemon.on_dnd_toggle.connect ((dnd) => {
                this.controlCenter.set_switch_dnd_state (dnd);
                subscribe (controlCenter.notification_count (), dnd);
            });

            // Update on start
            try {
                subscribe (notification_count (), get_dnd ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        public signal void subscribe (uint count, bool dnd);

        public bool reload_css () throws Error {
            bool result = Functions.load_css (style_path);
            if (result) controlCenter.reload_notifications_style ();
            return result;
        }

        public void reload_config () throws Error {
            ConfigModel.reload_config ();
        }

        public void change_config_value (string name,
                                         Variant value,
                                         bool write_to_file = true,
                                         string ? path = null) throws Error {
            ConfigModel.instance.change_value (name,
                                               value,
                                               write_to_file,
                                               path);
        }

        public bool get_visibility () throws DBusError, IOError {
            return controlCenter.get_visibility ();
        }

        public void close_all_notifications () throws DBusError, IOError {
            controlCenter.close_all_notifications ();
            notiDaemon.close_all_notifications ();
        }

        public uint notification_count () throws DBusError, IOError {
            return controlCenter.notification_count ();
        }

        public void toggle_visibility () throws DBusError, IOError {
            if (controlCenter.toggle_visibility ()) {
                notiDaemon.set_noti_window_visibility (false);
            }
        }

        public bool toggle_dnd () throws DBusError, IOError {
            return notiDaemon.toggle_dnd ();
        }

        public void set_dnd (bool state) throws DBusError, IOError {
            notiDaemon.set_dnd (state);
        }

        public bool get_dnd () throws DBusError, IOError {
            return notiDaemon.get_dnd ();
        }

        public void add_notification (NotifyParams param)
        throws DBusError, IOError {
            controlCenter.add_notification (param, notiDaemon);
        }

        public void close_notification (uint32 id) throws DBusError, IOError {
            controlCenter.close_notification (id);
        }
    }
}
