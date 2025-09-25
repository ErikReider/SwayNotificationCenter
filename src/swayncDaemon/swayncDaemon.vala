namespace SwayNotificationCenter {
    public struct Data {
        public bool dnd;
        public bool cc_open;
        public uint count;
        public bool inhibited;
    }

    [DBus (name = "org.erikreider.swaync.cc")]
    public class SwayncDaemon : Object {
        public NotiDaemon noti_daemon;
        public XdgActivationHelper xdg_activation;

        private GenericSet<string> inhibitors = new GenericSet<string> (str_hash, str_equal);
        public bool inhibited { get; set; default = false; }
        [DBus (visible = false)]
        public signal void inhibited_changed (uint length);

        private Array<BlankWindow> blank_windows = new Array<BlankWindow> ();

        // Only set on swaync start due to some limitations of GtkLayerShell
        [DBus (visible = false)]
        public bool use_layer_shell { get; private set; }
        [DBus (visible = false)]
        public bool has_layer_on_demand { get; private set; }

        public SwayncDaemon () {
            // Init noti_daemon
            this.use_layer_shell = ConfigModel.instance.layer_shell;
            this.has_layer_on_demand = use_layer_shell && GtkLayerShell.get_protocol_version () >= 4;
            this.noti_daemon = new NotiDaemon (this);
            this.xdg_activation = new XdgActivationHelper ();
            Bus.own_name (BusType.SESSION, "org.freedesktop.Notifications",
                          BusNameOwnerFlags.NONE,
                          on_noti_bus_aquired,
                          () => {},
                          () => {
                stderr.printf (
                    "Could not acquire notification name. " +
                    "Please close any other notification daemon " +
                    "like mako or dunst\n");
                Process.exit (1);
            });

            noti_daemon.on_dnd_toggle.connect ((dnd) => {
                try {
                    subscribe_v2 (noti_daemon.control_center.notification_count (),
                               dnd,
                               get_visibility (),
                               inhibited);
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
            });

            // Update on start
            try {
                subscribe_v2 (notification_count (),
                           get_dnd (),
                           get_visibility (),
                           inhibited);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }

            monitors.items_changed.connect (monitors_changed);
            Idle.add_once (() => monitors_changed (0, 0, monitors.get_n_items ()));
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

        private void monitors_changed (uint position, uint removed, uint added) {
            bool visible = noti_daemon.control_center.get_visibility ();

            for (uint i = 0; i < removed; i++) {
                unowned BlankWindow win = blank_windows.index (position + i);
                win.close ();
                blank_windows.remove_index (position + i);
            }

            for (uint i = 0; i < added; i++) {
                Gdk.Monitor monitor = (Gdk.Monitor) monitors.get_item (position + i);
                BlankWindow win = new BlankWindow (monitor);
                win.set_visible (visible);
                blank_windows.insert_val (position + i, win);
            }

            // Set preferred output
            try {
                set_cc_monitor (
                    ConfigModel.instance.control_center_preferred_output);
                set_noti_window_monitor (
                    ConfigModel.instance.notification_window_preferred_output);
            } catch (Error e) {
                critical (e.message);
            }
        }

        [DBus (visible = false)]
        public void show_blank_windows (Gdk.Monitor ? ref_monitor) {
            if (!use_layer_shell || !ConfigModel.instance.layer_shell_cover_screen) {
                return;
            }
            foreach (unowned BlankWindow win in blank_windows.data) {
                if (win.monitor != ref_monitor) {
                    win.show ();
                }
            }
        }

        [DBus (visible = false)]
        public void hide_blank_windows () {
            if (!use_layer_shell) return;
            foreach (unowned BlankWindow win in blank_windows.data) {
                win.hide ();
            }
        }

        /// DBus

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
            noti_daemon.control_center.add_widgets ();
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
            return noti_daemon.control_center.notification_count ();
        }

        /** Toggles the visibility of the controlcenter */
        public void toggle_visibility () throws DBusError, IOError {
            if (noti_daemon.control_center.toggle_visibility ()) {
                noti_daemon.set_noti_window_visibility (false);
            }
        }

        /** Sets the visibility of the controlcenter */
        public void set_visibility (bool visibility) throws DBusError, IOError {
            noti_daemon.control_center.set_visibility (visibility);
            if (visibility) noti_daemon.set_noti_window_visibility (false);
        }

        /** Toggles the current Do Not Disturb state */
        public bool toggle_dnd () throws DBusError, IOError {
            return noti_daemon.toggle_dnd ();
        }

        /** Sets the current Do Not Disturb state */
        public void set_dnd (bool state) throws DBusError, IOError {
            noti_daemon.set_do_not_disturb (state);
        }

        /** Gets the current Do Not Disturb state */
        public bool get_dnd () throws DBusError, IOError {
            return noti_daemon.get_do_not_disturb ();
        }

        /** Closes a specific notification with the `id` */
        public void close_notification (uint32 id) throws DBusError, IOError {
            noti_daemon.control_center.close_notification (id, true);
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
            if (inhibitors.contains (application_id)) return false;
            inhibitors.add (application_id);
            inhibited = inhibitors.length > 0;
            inhibited_changed (inhibitors.length);
            subscribe_v2 (noti_daemon.control_center.notification_count (),
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
            if (!inhibitors.remove (application_id)) return false;
            inhibited = inhibitors.length > 0;
            inhibited_changed (inhibitors.length);
            subscribe_v2 (noti_daemon.control_center.notification_count (),
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
            if (inhibitors.length == 0) return false;
            inhibitors.remove_all ();
            inhibited = false;
            inhibited_changed (0);
            subscribe_v2 (noti_daemon.control_center.notification_count (),
                       noti_daemon.dnd,
                       get_visibility (),
                       inhibited);
            return true;
        }

        public bool set_cc_monitor (string name) throws DBusError, IOError {
            unowned Gdk.Monitor ? monitor = Functions.try_get_monitor (name);
            if (monitor == null) {
                return false;
            }

            noti_daemon.control_center.set_monitor (monitor);
            return true;
        }

        public bool set_noti_window_monitor (string name) throws DBusError, IOError {
            unowned Gdk.Monitor ? monitor = Functions.try_get_monitor (name);
            if (monitor == null) {
                return false;
            }

            NotificationWindow.instance.set_monitor (monitor);
            return true;
        }
    }
}
