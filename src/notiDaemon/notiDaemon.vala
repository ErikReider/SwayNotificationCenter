namespace SwayNotificationCenter {
    [DBus (name = "org.freedesktop.Notifications")]
    public class NotiDaemon : Object {
        private uint32 noti_id = 0;

        public bool dnd { get; set; default = false; }

        private HashTable<string, uint32> synchronous_ids =
            new HashTable<string, uint32> (str_hash, str_equal);

        public ControlCenter control_center;

        public unowned SwayncDaemon swaync_daemon;

        public NotiDaemon (SwayncDaemon swaync_daemon) {
            this.swaync_daemon = swaync_daemon;

            this.notify["dnd"].connect (() => on_dnd_toggle (dnd));

            on_dnd_toggle.connect ((dnd) => {
                if (!dnd || NotificationWindow.is_null) return;
                NotificationWindow.instance.close_all_notifications ((noti) => {
                    return noti.param.urgency != UrgencyLevels.CRITICAL;
                });
            });

            // Init dnd from gsettings
            self_settings.bind ("dnd-state", this, "dnd", SettingsBindFlags.DEFAULT);

            this.control_center = new ControlCenter (swaync_daemon, this);
        }

        /**
         * Changes the popup-notification window visibility.
         * Closes all notifications and hides window if `value` is false
         */
        public void set_noti_window_visibility (bool value)
        throws DBusError, IOError {
            NotificationWindow.instance.change_visibility (value);
        }

        /** Toggles the current Do Not Disturb state */
        public bool toggle_dnd () throws DBusError, IOError {
            return dnd = !dnd;
        }

        /** Sets the current Do Not Disturb state */
        [DBus (name = "SetDnd")]
        public void set_do_not_disturb (bool state) throws DBusError, IOError {
            dnd = state;
        }

        /** Gets the current Do Not Disturb state */
        [DBus (name = "GetDnd")]
        public bool get_do_not_disturb () throws DBusError, IOError {
            return dnd;
        }

        /** Called when Do Not Disturb state changes */
        public signal void on_dnd_toggle (bool dnd);

        /** Method to close notification and send DISMISSED signal */
        public void manually_close_notification (uint32 id, bool timeout)
        throws DBusError, IOError {
            NotificationWindow.instance.close_notification (id, true);
            if (!timeout) {
                control_center.close_notification (id, true);
                NotificationClosed (id, ClosedReasons.DISMISSED);

                swaync_daemon.subscribe_v2 (control_center.notification_count (),
                                            dnd,
                                            control_center.get_visibility (),
                                            swaync_daemon.inhibited);
            }
        }

        /** Closes all popup and controlcenter notifications */
        public void close_all_notifications () throws DBusError, IOError {
            NotificationWindow.instance.close_all_notifications ();
            control_center.close_all_notifications ();
        }

        /** Closes latest popup notification */
        public void hide_latest_notification (bool close)
        throws DBusError, IOError {
            uint32 ? id = NotificationWindow.instance.get_latest_notification ();
            if (id == null) return;
            manually_close_notification (id, !close);
        }

        /** Activates the `action_index` action of the latest notification */
        public void latest_invoke_action (uint32 action_index)
        throws DBusError, IOError {
            NotificationWindow.instance.latest_notification_action (action_index);
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
         * not contain spaces. They are limited to alphanumeric characters
         * and dashes ("-").
         */
        [DBus (name = "GetCapabilities")]
        public string[] get_capabilities () throws DBusError, IOError {
            return {
                       "actions",
                       "body",
                       "body-markup",
                       "body-images",
                       "persistence",
                       "synchronous",
                       "private-synchronous",
                       "x-canonical-private-synchronous",
                       "inline-reply",
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
        [DBus (name = "Notify")]
        public uint32 new_notification (string app_name,
                                        uint32 replaces_id,
                                        string app_icon,
                                        string summary,
                                        string body,
                                        string[] actions,
                                        HashTable<string, Variant> hints,
                                        int expire_timeout) throws DBusError, IOError {
            uint32 id = replaces_id;
            if (replaces_id == 0 || replaces_id > noti_id) id = ++noti_id;

            var param = new NotifyParams (
                id,
                app_name,
                replaces_id,
                app_icon,
                summary,
                body,
                actions,
                hints,
                expire_timeout);

            // The notification visibility state
            NotificationStatusEnum state = NotificationStatusEnum.ENABLED;
            unowned OrderedHashTable<NotificationVisibility> visibilities =
                ConfigModel.instance.notification_visibility;
            foreach (string key in visibilities.get_keys ()) {
                unowned NotificationVisibility vis = visibilities[key];
                if (!vis.matches_notification (param)) continue;
                state = vis.state;
                if (vis.override_urgency != UNSET) {
                    debug ("override urgency to %s\n", vis.override_urgency.to_string ());
                    param.urgency = UrgencyLevels.from_value (vis.override_urgency.to_byte ());
                }
                break;
            }

            debug ("Notification: %s\n", param.to_string ());

            // Get the notification id to replace
            uint32 replace_notification = 0;
            if (id == replaces_id) {
                replace_notification = id;
            } else if (param.synchronous != null
                       && param.synchronous.length > 0) {
                // Tries replacing without replaces_id instead
                uint32 r_id;
                // if there is any notification to replace
                if (synchronous_ids.lookup_extended (
                        param.synchronous, null, out r_id)) {
                    replace_notification = r_id;
                }
                synchronous_ids.set (param.synchronous, id);
            }

            bool show_notification = state == NotificationStatusEnum.ENABLED
                                     || state == NotificationStatusEnum.TRANSIENT;
            // Don't show the notification window if the control center is open
            if (control_center.get_visibility ()) {
                show_notification = false;
            }

            bool bypass_dnd = param.urgency == UrgencyLevels.CRITICAL || param.swaync_bypass_dnd;
            // Don't show the notification window if dnd or inhibited
            if (!bypass_dnd && (dnd || swaync_daemon.inhibited)) {
                show_notification = false;
            }

            if (show_notification) {
                if (replace_notification > 0) {
                    NotificationWindow.instance.replace_notification (replace_notification, param);
                } else {
                    NotificationWindow.instance.add_notification (param);
                }
            } else if (replace_notification > 0) {
                // Remove the old notification due to it not being replaced
                NotificationWindow.instance.close_notification (replace_notification, false);
            }

            // Only add notification to CC if it isn't IGNORED and not transient/TRANSIENT
            if (state != NotificationStatusEnum.IGNORED
                && state != NotificationStatusEnum.TRANSIENT
                && !param.transient) {
                    if (replace_notification > 0) {
                        control_center.replace_notification (replace_notification, param);
                    } else {
                        control_center.add_notification (param);
                    }
            } else if (replace_notification > 0) {
                // Remove the old notification due to it not being replaced
                control_center.close_notification (replace_notification, false);
            }

#if WANT_SCRIPTING
            if (param.swaync_no_script) {
                debug ("Skipped scripts for this notification\n");
                return id;
            }
            // Run the first script if notification meets requirements
            OrderedHashTable<Script> scripts = ConfigModel.instance.scripts;
            if (scripts.length == 0) return id;
            this.run_scripts (param, ScriptRunOnType.RECEIVE);
#endif
            return id;
        }

        /**
         * Runs scripts that meet the requirements of the given `param`.
         */
        [DBus (visible = false)]
        public void run_scripts (NotifyParams param, ScriptRunOnType run_on) {
#if WANT_SCRIPTING
            if (param.swaync_no_script) {
                debug ("Skipped action scripts for this notification\n");
                return;
            }
            // Run the first script if notification meets requirements
            OrderedHashTable<Script> scripts = ConfigModel.instance.scripts;
            if (scripts.length == 0) return;
            foreach (string key in scripts.get_keys ()) {
                unowned Script script = scripts[key];
                if (!script.matches_notification (param)) continue;
                if (script.run_on != run_on) continue;

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
                            var _hints = new HashTable<string, Variant> (
                                str_hash,
                                str_equal);
                            // Disable scripts for this notification
                            _hints.insert ("SWAYNC_NO_SCRIPT", true);
                            _hints.insert ("urgency",
                                           UrgencyLevels.CRITICAL.to_byte ());

                            string _summary = "Failed to run script: %s".printf (key);
                            string _body = "<b>Output:</b> " + error_msg;
                            this.new_notification ("SwayNotificationCenter",
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
        [DBus (name = "CloseNotification")]
        public void close_notification (uint32 id) throws DBusError, IOError {
            NotificationWindow.instance.close_notification (id, true);
            control_center.close_notification (id, true);
            NotificationClosed (id, ClosedReasons.CLOSED_BY_CLOSENOTIFICATION);
        }

        /**
         * This message returns the information on the server. Specifically, the
         * server name, vendor, and version number.
         */
        [DBus (name = "GetServerInformation")]
        public void get_server_information (out string name,
                                            out string vendor,
                                            out string version,
                                            out string spec_version)
        throws DBusError, IOError {
            name = "SwayNotificationCenter";
            vendor = "ErikReider";
            version = Constants.VERSIONNUM;
            spec_version = "1.3";
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

        /**
         * This signal can be emitted before a ActionInvoked signal. It
         * carries an activation token that can be used to activate a toplevel.
         */
        public signal void ActivationToken (uint32 id, string activation_token);

        /** To be used by the non-standard "inline-reply" capability */
        public signal void NotificationReplied (uint32 id, string text);
    }
}
