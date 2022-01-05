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

        /**
         * Called when Dot Not Disturb state changes and when
         * notification gets added/removed
         */
        public signal void subscribe (uint count, bool dnd);

        /** Reloads the CSS file */
        public bool reload_css () throws Error {
            bool result = Functions.load_css (style_path);
            if (result) controlCenter.reload_notifications_style ();
            return result;
        }

        /** Reloads the config file */
        public void reload_config () throws Error {
            ConfigModel.reload_config ();
        }

        /**
         * Changes `name` to `value`.
         *
         * If `write_to_file` is True, it will write to the users
         * config file (`~/.config/swaync/config.json`) or `path`
         * if it's a valid path. Otherwise the changes will only
         * apply to the current instance.
         */
        public void change_config_value (string name,
                                         Variant value,
                                         bool write_to_file = true,
                                         string ? path = null) throws Error {
            ConfigModel.instance.change_value (name,
                                               value,
                                               write_to_file,
                                               path);
        }

        /** Gets the controlcenter visibility */
        public bool get_visibility () throws DBusError, IOError {
            return controlCenter.get_visibility ();
        }

        /** Closes all popup and controlcenter notifications */
        public void close_all_notifications () throws DBusError, IOError {
            notiDaemon.close_all_notifications ();
        }

        /** Gets the current controlcenter notification count */
        public uint notification_count () throws DBusError, IOError {
            return controlCenter.notification_count ();
        }

        /** Toggles the visibility of the controlcenter */
        public void toggle_visibility () throws DBusError, IOError {
            if (controlCenter.toggle_visibility ()) {
                notiDaemon.set_noti_window_visibility (false);
            }
        }

        /** Sets the visibility of the controlcenter */
        public void set_visibility (bool visibility) throws DBusError, IOError {
            controlCenter.set_visibility (visibility);
        }

        /** Toggles the current Do Not Disturb state */
        public bool toggle_dnd () throws DBusError, IOError {
            return notiDaemon.toggle_dnd ();
        }

        /** Sets the current Do Not Disturb state */
        public void set_dnd (bool state) throws DBusError, IOError {
            notiDaemon.set_dnd (state);
        }

        /** Gets the current Do Not Disturb state */
        public bool get_dnd () throws DBusError, IOError {
            return notiDaemon.get_dnd ();
        }

        /** Adds a new notification */
        public void add_notification (NotifyParams param)
        throws DBusError, IOError {
            controlCenter.add_notification (param, notiDaemon);
        }

        /** Closes a specific notification with the `id` */
        public void close_notification (uint32 id) throws DBusError, IOError {
            controlCenter.close_notification (id);
        }
    }
}
