namespace SwayNotificatonCenter {
    public enum ClosedReasons {
        EXPIRED = 1,
        DISMISSED = 2,
        CLOSED_BY_CLOSENOTIFICATION = 3,
        UNDEFINED = 4;
    }

    public enum UrgencyLevels {
        LOW = 0,
        NORMAL = 1,
        CRITICAL = 2;

        public static UrgencyLevels from_value (int val) {
            switch (val) {
                case 0:
                    return LOW;
                case 1:
                    return NORMAL;
                case 2:
                    return CRITICAL;
                default:
                    return NORMAL;
            }
        }

        public string to_string () {
            switch (this) {
                case LOW:
                    return "Low";
                case NORMAL:
                    return "Normal";
                case CRITICAL:
                    return "Critical";
            }
            return "Normal";
        }
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

        public string to_string () {
            if (identifier == null || name == null) return "None";
            return @"Name: $name, Id: $identifier";
        }
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
        public UrgencyLevels urgency { get; set; }

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
                    case "urgency":
                        if (hint_value.is_of_type (GLib.VariantType.BYTE)) {
                            urgency = UrgencyLevels.from_value (hint_value.get_byte ());
                        }
                        break;
                }
            }
        }

        public string to_string () {
            var params = new HashTable<string, string ? >(str_hash, str_equal);

            params.set ("applied_id", applied_id.to_string ());
            params.set ("app_name", app_name);
            params.set ("replaces_id", replaces_id.to_string ());
            params.set ("app_icon", app_icon);
            params.set ("default_action", default_action.to_string ());
            params.set ("summary", summary);
            params.set ("body", "\t" + body);
            string[] _hints = {};
            foreach (var key in hints.get_keys ()) {
                Variant v = hints[key];
                string data = "data";
                if (!key.contains ("image") && !key.contains ("icon")) {
                    data = v.print (true);
                }
                _hints += @"\n\t$key: " + data;
            }
            params.set ("hints", string.joinv ("", _hints));
            params.set ("expire_timeout", expire_timeout.to_string ());
            params.set ("time", "\t" + time.to_string ());

            params.set ("action_icons", action_icons.to_string ());
            params.set ("image_data", image_data.is_initialized.to_string ());
            params.set ("icon_data", icon_data.is_initialized.to_string ());
            params.set ("image_path", image_path);
            params.set ("desktop_entry", desktop_entry);
            params.set ("category", category);
            params.set ("resident", resident.to_string ());
            params.set ("urgency", urgency.to_string ());
            string[] _actions = {};
            foreach (var _action in actions) {
                _actions += "\n\t" + _action.to_string ();
            }
            params.set ("actions", string.joinv ("", _actions));

            string[] result = {};
            foreach (var k in params.get_keys ()) {
                string ? v = params[k];
                result += @"$k:\t\t" + v;
            }
            return "\n" + string.joinv ("\n", result);
        }
    }
}
