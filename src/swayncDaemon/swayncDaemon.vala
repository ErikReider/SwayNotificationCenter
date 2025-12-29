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
        public bool inhibited { get; private set; default = false; }
        internal signal void inhibited_changed (uint length);

        public SwayncDaemon () {
            subscribe_v2.connect ((count, dnd, visible, inhibited) => {
                debug ("Emitted subscribe_v2: %u, %s, %s, %s",
                       count, dnd.to_string (), visible.to_string (), inhibited.to_string ());
            });
        }

        internal inline void emit_subscribe () {
            try {
                swaync_daemon.subscribe_v2 (noti_daemon.n_notifications,
                                            get_dnd (),
                                            get_visibility (),
                                            inhibited);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
        }

        /** Gets subscribe data but in one call */
        [DBus (name = "GetSubscribeData")]
        public inline Data get_subscribe_data () throws Error {
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
        public inline void change_config_value (string name,
                                                Variant value,
                                                bool write_to_file = true,
                                                string ?path = null) throws Error {
            ConfigModel.instance.change_value (name,
                                               value,
                                               write_to_file,
                                               path);
        }

        /** Gets the Control Center visibility */
        public inline bool get_visibility () throws DBusError, IOError {
            return control_center.get_visibility ();
        }

        /** Closes latest popup notification */
        public inline void hide_latest_notifications (bool close)
        throws DBusError, IOError {
            noti_daemon.hide_latest_floating_notification (close);
        }

        /** Hides all popup notifications (closes transient) */
        public inline void hide_all_notifications () throws DBusError, IOError {
            noti_daemon.remove_all_floating_notifications (true, null);
        }

        /** Closes all popup and Control Center notifications */
        public inline void close_all_notifications () throws DBusError, IOError {
            noti_daemon.request_dismiss_all_notifications (ClosedReasons.DISMISSED);
        }

        /** Gets the current Control Center notification count */
        public inline uint notification_count () throws DBusError, IOError {
            return noti_daemon.n_notifications;
        }

        /** Toggles the visibility of the Control Center */
        public void toggle_visibility () throws DBusError, IOError {
            if (control_center.toggle_visibility ()) {
                noti_daemon.remove_all_floating_notifications (false, null);
            }
        }

        /** Sets the visibility of the Control Center */
        public void set_visibility (bool visibility) throws DBusError, IOError {
            control_center.set_visibility (visibility);
            if (visibility) {
                noti_daemon.remove_all_floating_notifications (false, null);
            }
        }

        /** Toggles the current Do Not Disturb state */
        public inline bool toggle_dnd () throws DBusError, IOError {
            noti_daemon.dnd = !noti_daemon.dnd;
            return noti_daemon.dnd;
        }

        /** Sets the current Do Not Disturb state */
        public inline void set_dnd (bool state) throws DBusError, IOError {
            noti_daemon.dnd = state;
        }

        /** Gets the current Do Not Disturb state */
        public inline bool get_dnd () throws DBusError, IOError {
            return noti_daemon.dnd;
        }

        /** Closes a specific notification with the `id` */
        public inline void close_notification (uint32 id) throws DBusError, IOError {
            noti_daemon.close_notification (id);
        }

        /** Activates the `action_index` action of the latest floating notification */
        public inline void latest_invoke_action (uint32 action_index)
        throws DBusError, IOError {
            noti_daemon.invoke_latest_floating_action (action_index);
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
            emit_subscribe ();
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
            emit_subscribe ();
            return true;
        }

        /** Get the number of inhibitors */
        public inline uint number_of_inhibitors () throws DBusError, IOError {
            return inhibitors.length;
        }

        /** Get if is inhibited */
        public inline bool is_inhibited () throws DBusError, IOError {
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
            emit_subscribe ();
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
