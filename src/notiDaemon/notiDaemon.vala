namespace SwayNotificatonCenter {
    [DBus (name = "org.freedesktop.Notifications")]
    public class NotiDaemon : Object {

        private uint32 noti_id = 0;
        private bool dnd = false;

        public NotiWindow notiWin;
        private DBusInit dbusInit;

        public NotiDaemon (DBusInit dbusInit) {
            this.dbusInit = dbusInit;
            this.notiWin = new NotiWindow (dbusInit);
        }

        public void set_noti_window_visibility (bool value)
        throws DBusError, IOError {
            notiWin.change_visibility (value);
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
            uint32 id = replaces_id;
            if (replaces_id == 0 || replaces_id > noti_id) {
                noti_id++;
                id = noti_id;
            }

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
            if (!dbusInit.ccDaemon.get_visibility () && !dnd) {
                notiWin.add_notification (param, this);
            }
            dbusInit.ccDaemon.add_notification (param);
            return id;
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

        public void click_close_notification (uint32 id) throws DBusError, IOError {
            CloseNotification (id);
            dbusInit.ccDaemon.close_notification (id);
        }

        public void close_all_notifications () throws DBusError, IOError {
            notiWin.close_all_notifications ();
        }

        // Only remove the popup without removing the it from the panel
        public void CloseNotification (uint32 id) throws DBusError, IOError {
            notiWin.close_notification (id);
        }

        public string[] GetCapabilities () throws DBusError, IOError {
            return {
                       "actions",
                       "body",
                       "persistence",
            };
        }

        public void GetServerInformation (out string name,
                                          out string vendor,
                                          out string version,
                                          out string spec_version)
        throws DBusError, IOError {
            name = "SwayNotificationCenter";
            vendor = "ErikReider";
            version = "0.1";
            spec_version = "1.2";
        }

        public signal void NotificationClosed (uint32 id, uint32 reason);

        public signal void ActionInvoked (uint32 id, string action_key);
    }


    public struct Image_Data {
        int width;
        int height;
        int rowstride;
        bool has_alpha;
        int bits_per_sample;
        int channels;
        unowned uint8[] data;

        bool is_initialized;
    }

    public struct Action {
        string identifier { get; set; }
        string name { get; set; }
    }

    public struct NotifyParams {
        public uint32 applied_id { get; set; }
        public string app_name { get; set; }
        public uint32 replaces_id { get; set; }
        public string app_icon { get; set; }
        public Action default_action { get; set; }
        public string summary { get; set; }
        public string body { get; set; }
        public HashTable<string, Variant> hints { get; set; }
        public int expire_timeout { get; set; }
        public int64 time { get; set; } // Epoch in seconds

        // Hints
        public bool action_icons { get; set; }
        public Image_Data image_data { get; set; }
        public Image_Data icon_data { get; set; }
        public string image_path { get; set; }
        public string desktop_entry { get; set; }
        public string category { get; set; }
        public bool resident { get; set; }

        public Action[] actions { get; set; }

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
            this.hints = hints;
            this.expire_timeout = expire_timeout;
            this.time = (int64) (GLib.get_real_time () * 0.000001);

            s_hints ();

            Action[] ac_array = {};
            if (actions.length > 1 && actions.length % 2 == 0) {
                for (int i = 0; i < actions.length; i++) {
                    var action = Action ();
                    action._identifier = actions[i];
                    action._name = actions[i + 1];
                    if (action._name != null && action._identifier != null
                        && action._name != "" && action._identifier != "") {

                        if (action._identifier.down () == "default") {
                            default_action = action;
                        } else {
                            ac_array += action;
                        }
                    }
                    i++;
                }
            }
            this.actions = ac_array;
        }

        private void s_hints () {
            foreach (var hint in hints.get_keys ()) {
                Variant hint_value = hints[hint];
                switch (hint) {
                    case "action-icons":
                        if (hint_value.is_of_type (GLib.VariantType.BOOLEAN)) {
                            action_icons = hint_value.get_boolean ();
                        }
                        break;
                    case "image-data":
                    case "image_data":
                    case "icon_data":
                        if (image_data.is_initialized) break;
                        var img_d = Image_Data ();
                        // Read each value
                        // https://specifications.freedesktop.org/notification-spec/latest/ar01s05.html
                        img_d.width = hint_value.get_child_value (0).get_int32 ();
                        img_d.height = hint_value.get_child_value (1).get_int32 ();
                        img_d.rowstride = hint_value.get_child_value (2).get_int32 ();
                        img_d.has_alpha = hint_value.get_child_value (3).get_boolean ();
                        img_d.bits_per_sample = hint_value.get_child_value (4).get_int32 ();
                        img_d.channels = hint_value.get_child_value (5).get_int32 ();
                        // Read the raw image data
                        img_d.data = (uint8[]) hint_value.get_child_value (6).get_data ();

                        img_d.is_initialized = true;
                        if (hint == "icon_data") {
                            icon_data = img_d;
                        } else {
                            image_data = img_d;
                        }
                        break;
                    case "image-path":
                    case "image_path":
                        if (hint_value.is_of_type (GLib.VariantType.STRING)) {
                            image_path = hint_value.get_string ();
                        }
                        break;
                    case "desktop-entry":
                        if (hint_value.is_of_type (GLib.VariantType.STRING)) {
                            desktop_entry = hint_value.get_string ();
                        }
                        break;
                    case "category":
                        if (hint_value.is_of_type (GLib.VariantType.STRING)) {
                            category = hint_value.get_string ();
                        }
                        break;
                    case "resident":
                        if (hint_value.is_of_type (GLib.VariantType.BOOLEAN)) {
                            resident = hint_value.get_boolean ();
                        }
                        break;
                }
            }
        }
    }
}
