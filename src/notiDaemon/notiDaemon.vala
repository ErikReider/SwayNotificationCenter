namespace SwayNotificationCenter {
    [DBus (name = "org.freedesktop.Notifications")]
    public class NotiDaemon : Object {
        private uint32 noti_id = 0;
        private bool dnd = false;
        private HashTable<string, uint32> synchronous_ids =
            new HashTable<string, uint32>(str_hash, str_equal);

        public CcDaemon ccDaemon;
        public NotiWindow notiWindow;

        public NotiDaemon () {
            this.ccDaemon = new CcDaemon (this);
            Bus.own_name (BusType.SESSION, "org.erikreider.swaync.cc",
                          BusNameOwnerFlags.NONE,
                          on_cc_bus_aquired,
                          () => {},
                          () => {
                stderr.printf (
                    "Could not aquire control center name\n");
                Process.exit (1);
            });

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

        /**
         * Changes the popup-notification window visibility.
         * Closes all notifications and hides window if `value` is false
         */
        public void set_noti_window_visibility (bool value)
        throws DBusError, IOError {
            notiWindow.change_visibility (value);
        }

        /** Toggles the current Do Not Disturb state */
        public bool toggle_dnd () throws DBusError, IOError {
            on_dnd_toggle (dnd = !dnd);
            return dnd;
        }

        /** Sets the current Do Not Disturb state */
        public void set_dnd (bool state) throws DBusError, IOError {
            on_dnd_toggle (state);
            dnd = state;
        }

        /** Gets the current Do Not Disturb state */
        public bool get_dnd () throws DBusError, IOError {
            return dnd;
        }

        /** Called when Do Not Disturb state changes */
        public signal void on_dnd_toggle (bool dnd);

        /** Method to close notification and send DISMISSED signal */
        public void manually_close_notification (uint32 id, bool timeout)
        throws DBusError, IOError {
            notiWindow.close_notification (id);
            if (!timeout) {
                ccDaemon.controlCenter.close_notification (id);
                NotificationClosed (id, ClosedReasons.DISMISSED);
            }
        }

        /** Closes all popup and controlcenter notifications */
        public void close_all_notifications () throws DBusError, IOError {
            notiWindow.close_all_notifications ();
            ccDaemon.controlCenter.close_all_notifications ();
        }

        /*
         * D-Bus Specification
         * https://specifications.freedesktop.org/notification-spec/latest/ar01s09.html
         */

        /**
         * It returns an array of strings. Each string describes an optional
         * capability implemented by the server.
         *
         * New vendor-specific caps may be specified as long as they start with
         * "x-vendor". For instance, "x-gnome-foo-cap". Capability names must
         * not contain spaces. They are limited to alpha-numeric characters
         * and dashes ("-").
         */
        public string[] GetCapabilities () throws DBusError, IOError {
            return {
                       "actions",
                       "body",
                       "body-markup",
                       "body-images",
                       "body-hyperlinks",
                       "persistence",
                       "synchronous",
                       "private-synchronous",
                       "x-canonical-private-synchronous",
            };
        }

        /**
         * Sends a notification to the notification server.
         *
         * If replaces_id is 0, the return value is a UINT32 that represent
         * the notification. It is unique, and will not be reused unless a
         * MAXINT number of notifications have been generated. An acceptable
         * implementation may just use an incrementing counter for the ID.
         * The returned ID is always greater than zero. Servers must make
         * sure not to return zero as an ID.
         *
         * If replaces_id is not 0, the returned value is the same value
         * as replaces_id.
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

            debug ("Notification: %s\n", param.to_string ());

            // Replace notification logic
            string ? synchronous = param.synchronous;
            if (id == replaces_id) {
                notiWindow.close_notification (id);
                ccDaemon.controlCenter.close_notification (id, true);
                param.replaces = true;
            } else if (synchronous != null
                       && synchronous.length > 0) {
                // Tries replacing without replaces_id instead
                if (synchronous in synchronous_ids) {
                    uint32 r_id = synchronous_ids.get (synchronous);

                    // Close the notification
                    notiWindow.close_notification (r_id);
                    ccDaemon.controlCenter.close_notification (r_id, true);
                    param.replaces = true;
                }
                synchronous_ids.set (synchronous, id);
            }

            if (!ccDaemon.controlCenter.get_visibility ()) {
                if (param.urgency == UrgencyLevels.CRITICAL ||
                    (!dnd && param.urgency != UrgencyLevels.CRITICAL)) {
                    notiWindow.add_notification (param, this);
                }
            }
            ccDaemon.controlCenter.add_notification (param, this);

#if WANT_SCRIPTING
            if (param.swaync_no_script) {
                debug ("Skipped scripts for this notification\n");
                return id;
            }
            // Run the first script if notification meets requirements
            HashTable<string, Script> scripts = ConfigModel.instance.scripts;
            if (scripts.length == 0) return id;
            foreach (string key in scripts.get_keys ()) {
                unowned Script script = scripts[key];
                if (!script.matches_notification (param)) continue;

                script.run_script.begin (param, (obj, res) => {
                    // Gets the end status
                    string error_msg;
                    if (script.run_script.end (res, out error_msg)) return;

                    if (!ConfigModel.instance.script_fail_notify) {
                        stderr.printf (
                            "Failed to run script: \"%s\" with exec: \"%s\"\n",
                            key, script.exec);
                    } else {
                        // Send notification with error message
                        try {
                            var _hints = new HashTable<string, Variant>(
                                str_hash,
                                str_equal);
                            // Disable scripts for this notification
                            _hints.insert ("SWAYNC_NO_SCRIPT", true);
                            _hints.insert ("urgency",
                                           UrgencyLevels.CRITICAL.to_byte ());

                            string _summary = @"Failed to run script: $key";
                            string _body = "<b>Output:</b> " + error_msg;
                            this.Notify ("SwayNotificationCenter",
                                         0,
                                         "dialog-error",
                                         _summary,
                                         _body,
                                         {},
                                         _hints,
                                         -1);
                        } catch (Error e) {
                            stderr.printf ("NOTIFING SCRIPT-FAIL ERROR: %s\n",
                                           e.message);
                        }
                    }
                });
                break;
            }
#endif

            return id;
        }

        /**
         * Causes a notification to be forcefully closed and removed from the
         * user's view. It can be used, for example, in the event that what
         * the notification pertains to is no longer relevant, or to cancel a
         * notification with no expiration time.
         *
         * The NotificationClosed signal is emitted by this method.
         *
         * If the notification no longer exists, an empty D-BUS Error message
         * is sent back.
         */
        public void CloseNotification (uint32 id) throws DBusError, IOError {
            notiWindow.close_notification (id);
            ccDaemon.controlCenter.close_notification (id);
            NotificationClosed (id, ClosedReasons.CLOSED_BY_CLOSENOTIFICATION);
        }

        /**
         * This message returns the information on the server. Specifically, the
         * server name, vendor, and version number.
         */
        public void GetServerInformation (out string name,
                                          out string vendor,
                                          out string version,
                                          out string spec_version)
        throws DBusError, IOError {
            name = "SwayNotificationCenter";
            vendor = "ErikReider";
            version = Constants.versionNum;
            spec_version = "1.2";
        }

        /**
         * A completed notification is one that has timed out, or has been
         * dismissed by the user.
         *
         * The ID specified in the signal is invalidated before the signal
         * is sent and may not be used in any further communications
         * with the server.
         */
        public signal void NotificationClosed (uint32 id, uint32 reason);

        /**
         * This signal is emitted when one of the following occurs:
         *
         * - The user performs some global "invoking" action upon a
         * notification. For instance, clicking somewhere on the
         * notification itself.
         *
         * - The user invokes a specific action as specified in the original
         * Notify request. For example, clicking on an action button.
         *
         * #Note
         *
         * Clients should not assume the server will generate this signal.
         * Some servers may not support user interaction at all, or may not
         * support the concept of being able to "invoke" a notification.
         */
        public signal void ActionInvoked (uint32 id, string action_key);
    }
}
