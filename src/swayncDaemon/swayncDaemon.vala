namespace SwayNotificationCenter {
    public struct Data {
        public bool dnd;
        public bool cc_open;
        public uint count;
        public bool inhibited;
    }

    [DBus (name = "org.erikreider.swaync.cc")]
    public class SwayncDaemon : Object {
        private GenericSet<string> inhibitors = new GenericSet<string> (str_hash, str_equal);
        public bool inhibited { get; set; default = false; }
        internal signal void inhibited_changed (uint length);

        /** Gets subscribe data but in one call */
        [DBus (name = "GetSubscribeData")]
        public Data get_subscribe_data () throws Error {
            return Data () {
                       dnd = get_dnd (),
                       cc_open = get_visibility (),
                       count = notification_count (),
                       inhibited = is_inhibited (),
            };
        }

        /**
         * Called when Dot Not Disturb state changes, notification gets
         * added/removed, and when Control Center opens
         */
        public signal void subscribe_v2 (uint count, bool dnd, bool cc_open, bool inhibited);

        /**
         * Called when Dot Not Disturb state changes, notification gets
         * added/removed, Control Center opens, and when inhibitor state changes
         */
        [Version (deprecated = true, replacement = "SwayncDaemon.subscribe_v2")]
        public signal void subscribe (uint count, bool dnd, bool cc_open);

        /** Reloads the CSS file */
        public bool reload_css () throws Error {
            bool result = Functions.load_css (style_path);
            return result;
        }

        /** Reloads the config file */
        public void reload_config () throws Error {
            print ("\n");
            message ("Reloading config\n");
            ConfigModel.reload_config ();
            control_center.add_widgets ();
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
                                         string ?path = null) throws Error {
            ConfigModel.instance.change_value (name,
                                               value,
                                               write_to_file,
                                               path);
        }

        /** Gets the controlcenter visibility */
        public bool get_visibility () throws DBusError, IOError {
            return control_center.get_visibility ();
        }

        /** Closes latest popup notification */
        public void hide_latest_notifications (bool close)
        throws DBusError, IOError {
            noti_daemon.hide_latest_notification (close);
        }

        /** Closes all popup notifications */
        public void hide_all_notifications ()
        throws DBusError, IOError {
            noti_daemon.hide_all_notifications ();
        }

        /** Closes all popup and controlcenter notifications */
        public void close_all_notifications () throws DBusError, IOError {
            noti_daemon.close_all_notifications ();
        }

        /** Gets the current controlcenter notification count */
        public uint notification_count () throws DBusError, IOError {
            return notifications_widget.notification_count ();
        }

        /** Toggles the visibility of the controlcenter */
        public void toggle_visibility () throws DBusError, IOError {
            if (control_center.toggle_visibility ()) {
                floating_notifications.hide_all_notifications ();
            }
        }

        /** Sets the visibility of the controlcenter */
        public void set_visibility (bool visibility) throws DBusError, IOError {
            control_center.set_visibility (visibility);
            if (visibility) {
                floating_notifications.hide_all_notifications ();
            }
        }

        /** Toggles the current Do Not Disturb state */
        public bool toggle_dnd () throws DBusError, IOError {
            noti_daemon.dnd = !noti_daemon.dnd;
            return noti_daemon.dnd;
        }

        /** Sets the current Do Not Disturb state */
        public void set_dnd (bool state) throws DBusError, IOError {
            noti_daemon.dnd = state;
        }

        /** Gets the current Do Not Disturb state */
        public bool get_dnd () throws DBusError, IOError {
            return noti_daemon.dnd;
        }

        /** Closes a specific notification with the `id` */
        public void close_notification (uint32 id) throws DBusError, IOError {
            noti_daemon.manually_close_notification_id (id);
        }

        /** Activates the `action_index` action of the latest notification */
        public void latest_invoke_action (uint32 action_index)
        throws DBusError, IOError {
            noti_daemon.latest_invoke_action (action_index);
        }

        /**
         * Adds an inhibitor with the Application ID
         * (ex: "org.erikreider.swaysettings", "swayidle", etc...).
         *
         * @return  false if the `application_id` already exists, otherwise true.
         */
        public bool add_inhibitor (string application_id) throws DBusError, IOError {
            if (inhibitors.contains (application_id)) {
                return false;
            }
            inhibitors.add (application_id);
            inhibited = inhibitors.length > 0;
            inhibited_changed (inhibitors.length);
            subscribe_v2 (notifications_widget.notification_count (),
                          noti_daemon.dnd,
                          get_visibility (),
                          inhibited);
            return true;
        }

        /**
         * Removes an inhibitor with the Application ID
         * (ex: "org.erikreider.swaysettings", "swayidle", etc...).
         *
         * @return  false if the `application_id` doesn't exist, otherwise true
         */
        public bool remove_inhibitor (string application_id) throws DBusError, IOError {
            if (!inhibitors.remove (application_id)) {
                return false;
            }
            inhibited = inhibitors.length > 0;
            inhibited_changed (inhibitors.length);
            subscribe_v2 (notifications_widget.notification_count (),
                          noti_daemon.dnd,
                          get_visibility (),
                          inhibited);
            return true;
        }

        /** Get the number of inhibitors */
        public uint number_of_inhibitors () throws DBusError, IOError {
            return inhibitors.length;
        }

        /** Get if is inhibited */
        public bool is_inhibited () throws DBusError, IOError {
            return inhibited;
        }

        /** Clear all inhibitors */
        public bool clear_inhibitors () throws DBusError, IOError {
            if (inhibitors.length == 0) {
                return false;
            }
            inhibitors.remove_all ();
            inhibited = false;
            inhibited_changed (0);
            subscribe_v2 (notifications_widget.notification_count (),
                          noti_daemon.dnd,
                          get_visibility (),
                          inhibited);
            return true;
        }

        public bool set_cc_monitor (string name) throws DBusError, IOError {
            if (!app.use_layer_shell) {
                critical (
                    "Setting Control Center monitor isn't supported "
                    + "when layer shell is disabled!");
                return false;
            }
            unowned Gdk.Monitor ?monitor = Functions.try_get_monitor (name);
            if (monitor == null) {
                return false;
            }

            control_center.set_monitor (monitor);
            return true;
        }

        public bool set_noti_window_monitor (string name) throws DBusError, IOError {
            if (!app.use_layer_shell) {
                critical (
                    "Setting Notification Window monitor isn't supported "
                    + "when layer shell is disabled!");
                return false;
            }
            unowned Gdk.Monitor ?monitor = Functions.try_get_monitor (name);
            if (monitor == null) {
                return false;
            }

            floating_notifications.set_monitor (monitor);
            return true;
        }
    }
}
