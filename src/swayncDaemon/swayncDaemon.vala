namespace SwayNotificationCenter {
    [DBus (name = "org.erikreider.swaync.cc")]
    public class SwayncDaemon : Object {
        public NotiDaemon noti_daemon;

        public SwayncDaemon () {
            // Init noti_daemon
            this.noti_daemon = new NotiDaemon (this);
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

            noti_daemon.on_dnd_toggle.connect ((dnd) => {
                noti_daemon.control_center.set_switch_dnd_state (dnd);
                try {
                    subscribe (noti_daemon.control_center.notification_count (),
                               dnd,
                               get_visibility ());
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
            });

            // Update on start
            try {
                subscribe (notification_count (),
                           get_dnd (),
                           get_visibility ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        private void on_noti_bus_aquired (DBusConnection conn) {
            try {
                conn.register_object (
                    "/org/freedesktop/Notifications", noti_daemon);
            } catch (IOError e) {
                stderr.printf ("Could not register notification service\n");
                Process.exit (1);
            }
        }

        /**
         * Called when Dot Not Disturb state changes and when
         * notification gets added/removed
         */
        public signal void subscribe (uint count, bool dnd, bool cc_open);

        /** Reloads the CSS file */
        public bool reload_css () throws Error {
            bool result = Functions.load_css (style_path);
            if (result) noti_daemon.control_center.reload_notifications_style ();
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
            return noti_daemon.control_center.get_visibility ();
        }

        /** Closes latest popup notification */
        public void hide_latest_notifications (bool close)
        throws DBusError, IOError {
            noti_daemon.hide_latest_notification (close);
        }

        /** Closes all popup and controlcenter notifications */
        public void close_all_notifications () throws DBusError, IOError {
            noti_daemon.close_all_notifications ();
        }

        /** Gets the current controlcenter notification count */
        public uint notification_count () throws DBusError, IOError {
            return noti_daemon.control_center.notification_count ();
        }

        /** Toggles the visibility of the controlcenter */
        public void toggle_visibility () throws DBusError, IOError {
            if (noti_daemon.control_center.toggle_visibility ()) {
                noti_daemon.set_noti_window_visibility (false);
            }
            try {
                subscribe (noti_daemon.control_center.notification_count (),
                           get_dnd (),
                           get_visibility ());
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        /** Sets the visibility of the controlcenter */
        public void set_visibility (bool visibility) throws DBusError, IOError {
            noti_daemon.control_center.set_visibility (visibility);
            if (visibility) noti_daemon.set_noti_window_visibility (false);
            try {
                subscribe (noti_daemon.control_center.notification_count (),
                           get_dnd (),
                           visibility);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        /** Toggles the current Do Not Disturb state */
        public bool toggle_dnd () throws DBusError, IOError {
            return noti_daemon.toggle_dnd ();
        }

        /** Sets the current Do Not Disturb state */
        public void set_dnd (bool state) throws DBusError, IOError {
            noti_daemon.set_dnd (state);
        }

        /** Gets the current Do Not Disturb state */
        public bool get_dnd () throws DBusError, IOError {
            return noti_daemon.get_dnd ();
        }

        /** Closes a specific notification with the `id` */
        public void close_notification (uint32 id) throws DBusError, IOError {
            noti_daemon.control_center.close_notification (id);
        }
    }
}
