namespace SwayNotificationCenter {
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

        public uint8 to_byte () {
            return this;
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

    public struct ImageData {
        int width;
        int height;
        int rowstride;
        bool has_alpha;
        int bits_per_sample;
        int channels;
        unowned uint8[] data;

        bool is_initialized;
    }

    public class Action : Object {
        public string identifier { get; set; }
        public string name { get; set; }

        public string to_string () {
            if (identifier == null || name == null) return "None";
            return "Name: %s, Id: %s".printf (name, identifier);
        }
    }

    public class NotifyParams : Object {
        public uint32 applied_id { get; set; }
        public string app_name { get; set; }
        public uint32 replaces_id { get; set; }
        public string app_icon { get; set; }
        public Action ? default_action { get; set; }
        public string summary { get; set; }
        public string body { get; set; }
        public HashTable<string, Variant> hints { get; set; }
        public int expire_timeout { get; set; }
        public int64 time { get; set; } // Epoch in seconds

        // Hints
        public bool action_icons { get; set; }
        public ImageData image_data { get; set; }
        public ImageData icon_data { get; set; }
        public string image_path { get; set; }
        public string desktop_entry { get; set; }
        public string category { get; set; }
        public bool resident { get; set; }
        public bool transient { get; set; }
        public UrgencyLevels urgency { get; set; }
        /** Replaces the old notification with the same value of:
         * - x-canonical-private-synchronous
         * - synchronous
         */
        public string ? synchronous { get; set; }
        /** Used for notification progress bar (0->100) */
        public int value {
            get {
                return priv_value;
            }
            set {
                priv_value = value.clamp (0, 100);
            }
        }
        private int priv_value { private get; private set; }
        public bool has_synch { public get; private set; }

        /** Inline-replies */
        public Action ? inline_reply { get; set; }
        public string ? inline_reply_placeholder { get; set; }

        // Custom hints
        /** Disables scripting for notification */
        public bool swaync_no_script { get; set; }

        /** Always show the notification, regardless of dnd/inhibit state */
        public bool swaync_bypass_dnd { get; set; }

        public Array<Action> actions { get; set; }

        public DesktopAppInfo ? desktop_app_info = null;

        public string name_id;

        public string display_name;

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
            this.time = (int64) (get_real_time () * 0.000001);

            this.has_synch = false;

            parse_hints ();

            parse_actions (actions);

            // Try to get the desktop file
            string[] entries = {};
            if (desktop_entry != null) entries += desktop_entry.replace (".desktop", "");
            if (app_name != null) entries += app_name.replace (".desktop", "");
            foreach (string entry in entries) {
                var app_info = new DesktopAppInfo ("%s.desktop".printf (entry));
                // Checks if the .desktop file actually exists or not
                if (app_info is DesktopAppInfo) {
                    desktop_app_info = app_info;
                    break;
                }
            }

            // Set name_id
            this.name_id = this.desktop_entry ?? this.app_name ?? "";

            // Set display_name and make the first letter upper case
            string ? display_name = this.desktop_entry ?? this.app_name;
            if (desktop_app_info != null) {
                display_name = desktop_app_info.get_display_name ();
            }
            if (display_name == null || display_name.length == 0) {
                display_name = "Unknown";
            }
            this.display_name = display_name.splice (0, 1, display_name.up (1));
        }

        private void parse_hints () {
            foreach (var hint in hints.get_keys ()) {
                Variant hint_value = hints[hint];
                switch (hint) {
                    case "SWAYNC_NO_SCRIPT":
                        if (hint_value.is_of_type (VariantType.BOOLEAN)) {
                            swaync_no_script = hint_value.get_boolean ();
                        }
                        break;
                    case "SWAYNC_BYPASS_DND":
                        if (hint_value.is_of_type (VariantType.BOOLEAN)) {
                            swaync_bypass_dnd = hint_value.get_boolean ();
                        }
                        break;
                    case "value":
                        if (hint_value.is_of_type (VariantType.INT32)) {
                            this.has_synch = true;
                            value = hint_value.get_int32 ();
                        }
                        break;
                    case "synchronous":
                    case "private-synchronous":
                    case "x-canonical-private-synchronous":
                        if (hint_value.is_of_type (VariantType.STRING)) {
                            synchronous = hint_value.get_string ();
                        }
                        break;
                    case "action-icons":
                        if (hint_value.is_of_type (VariantType.BOOLEAN)) {
                            action_icons = hint_value.get_boolean ();
                        }
                        break;
                    case "image-data":
                    case "image_data":
                    case "icon_data":
                        if (image_data.is_initialized) break;
                        var img_d = ImageData ();
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
                        if (hint_value.is_of_type (VariantType.STRING)) {
                            image_path = hint_value.get_string ();
                        }
                        break;
                    case "desktop-entry":
                        if (hint_value.is_of_type (VariantType.STRING)) {
                            desktop_entry = hint_value.get_string ();
                        }
                        break;
                    case "category":
                        if (hint_value.is_of_type (VariantType.STRING)) {
                            category = hint_value.get_string ();
                        }
                        break;
                    case "resident":
                        if (hint_value.is_of_type (VariantType.BOOLEAN)) {
                            resident = hint_value.get_boolean ();
                        }
                        break;
                    case "transient":
                        if (hint_value.is_of_type (VariantType.BOOLEAN)) {
                            transient = hint_value.get_boolean ();
                        } else if (hint_value.is_of_type (VariantType.INT32)) {
                            transient = hint_value.get_int32 () == 1;
                        }
                        break;
                    case "urgency":
                        if (hint_value.is_of_type (VariantType.BYTE)) {
                            urgency = UrgencyLevels.from_value (hint_value.get_byte ());
                        }
                        break;
                    case "x-kde-reply-placeholder-text":
                        if (hint_value.is_of_type (VariantType.STRING)) {
                            inline_reply_placeholder = hint_value.get_string ();
                        }
                        break;
                }
            }
        }

        private void parse_actions (string[] actions) {
            Array<Action> parsed_actions = new Array<Action> ();
            if (actions.length > 1 && actions.length % 2 == 0) {
                for (int i = 0; i < actions.length; i++) {
                    var action = new Action ();
                    action.identifier = actions[i];
                    action.name = actions[i + 1];
                    if (action.name != null && action.identifier != null) {
                        string id = action.identifier.down ();
                        switch (id) {
                            case "default":
                                default_action = action;
                                break;
                            case "inline-reply":
                                if (action.name == "") {
                                    action.name = "Reply";
                                }
                                inline_reply = action;
                                break;
                            default:
                                parsed_actions.append_val (action);
                                break;
                        }
                    }
                    i++;
                }
            }
            this.actions = parsed_actions;
        }

        public string to_string () {
            var params = new HashTable<string, string ?> (str_hash, str_equal);

            params.set ("applied_id", applied_id.to_string ());
            params.set ("app_name", app_name);
            params.set ("replaces_id", replaces_id.to_string ());
            params.set ("app_icon", app_icon);
            params.set ("default_action", default_action == null
                        ? null : default_action.to_string ());
            params.set ("summary", summary);
            params.set ("body", "\t" + body);
            string[] _hints = {};
            foreach (var key in hints.get_keys ()) {
                Variant v = hints[key];
                string data = "data";
                if (!key.contains ("image") && !key.contains ("icon")) {
                    data = v.print (true);
                }
                _hints += "\n\t%s: %s".printf (key, data);
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
            foreach (var _action in actions.data) {
                _actions += "\n\t" + _action.to_string ();
            }
            params.set ("actions", string.joinv ("", _actions));
            params.set ("inline-reply", inline_reply == null
                        ? null : inline_reply.to_string ());

            string[] result = {};
            foreach (var k in params.get_keys ()) {
                string ? v = params[k];
                result += "%s:\t\t %s".printf (k, v);
            }
            return "\n" + string.joinv ("\n", result);
        }
    }
}
