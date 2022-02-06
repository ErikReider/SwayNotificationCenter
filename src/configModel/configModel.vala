namespace SwayNotificationCenter {
    public enum PositionX {
        RIGHT, LEFT, CENTER;

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (PositionX).class_ref ();
            return enumc.get_value_by_name (this.to_string ()).value_nick;
        }
    }

    public enum PositionY {
        TOP, BOTTOM;

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (PositionY).class_ref ();
            return enumc.get_value_by_name (this.to_string ()).value_nick;
        }
    }

    public enum ImageVisibility {
        ALWAYS, WHEN_AVAILABLE, NEVER;

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (ImageVisibility).class_ref ();
            return enumc.get_value_by_name (this.to_string ()).value_nick;
        }
    }

    public class Category : Object {
        public string ? sound { get; set; default = null; }
        public string ? icon { get; set; default = null; }

        public string to_string () {
            string[] fields = {};
            if (sound != null) fields += @"sound: $sound";
            if (icon != null) fields += @"icon: $icon";
            return string.joinv (", ", fields);
        }
    }

    public class Script : Object {
        public string ? exec { get; set; default = null; }

        public string ? app_name { get; set; default = null; }
        public string ? summary { get; set; default = null; }
        public string ? body { get; set; default = null; }
        public string ? urgency { get; set; default = null; }
        public string ? category { get; set; default = null; }

        public async bool run_script () {
            try {
                string[] spawn_env = Environ.get ();
                Pid child_pid;
                Process.spawn_async (
                    "/",
                    exec.split (" "),
                    spawn_env,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null,
                    out child_pid);

                // Close the child when the spawned process is idling
                int end_status = 0;
                ChildWatch.add (child_pid, (pid, status) => {
                    Process.close_pid (pid);
                    end_status = status;
                    run_script.callback ();
                });
                // Waits until `run_script.callback()` is called above
                yield;
                return end_status == 0;
            } catch (Error e) {
                stderr.printf ("Run_Script Error: %s\n", e.message);
                return false;
            }
        }

        public bool matches_notification (NotifyParams param) {
            if (exec == null) return false;

            if (app_name != null) {
                bool result = Regex.match_simple (
                    app_name, param.app_name,
                    RegexCompileFlags.JAVASCRIPT_COMPAT,
                    RegexMatchFlags.NOTEMPTY);
                if (!result) return false;
            }
            if (summary != null) {
                bool result = Regex.match_simple (
                    summary, param.summary,
                    RegexCompileFlags.JAVASCRIPT_COMPAT,
                    RegexMatchFlags.NOTEMPTY);
                if (!result) return false;
            }
            if (body != null) {
                bool result = Regex.match_simple (
                    body, param.body,
                    RegexCompileFlags.JAVASCRIPT_COMPAT,
                    RegexMatchFlags.NOTEMPTY);
                if (!result) return false;
            }
            if (urgency != null) {
                bool result = Regex.match_simple (
                    urgency, param.urgency.to_string (),
                    RegexCompileFlags.JAVASCRIPT_COMPAT,
                    RegexMatchFlags.NOTEMPTY);
                if (!result) return false;
            }
            if (category != null) {
                bool result = Regex.match_simple (
                    category, param.category,
                    RegexCompileFlags.JAVASCRIPT_COMPAT,
                    RegexMatchFlags.NOTEMPTY);
                if (!result) return false;
            }
            return true;
        }

        public string to_string () {
            string[] fields = {};
            if (app_name != null) fields += @"sound: $app_name";
            if (summary != null) fields += @"sound: $summary";
            if (body != null) fields += @"sound: $body";
            if (urgency != null) fields += @"sound: $urgency";
            if (category != null) fields += @"sound: $category";
            return string.joinv (", ", fields);
        }
    }

    public class ConfigModel : Object, Json.Serializable {

        private static ConfigModel _instance;
        private static string _path = "";

        /** Get the static singleton */
        public static unowned ConfigModel instance {
            get {
                if (_instance == null) _instance = new ConfigModel ();
                if (_path.length <= 0) _path = Functions.get_config_path (null);
                return _instance;
            }
        }

        /** Get the static singleton and reload the config */
        public static unowned ConfigModel init (string ? path) {
            _path = Functions.get_config_path (path);
            reload_config ();
            return _instance;
        }

        public delegate void ModifyNode (Json.Node node);

        /** Reloads the config and calls `ModifyNode` before deserializing */
        public static void reload_config (ModifyNode modify_cb = () => {}) {
            ConfigModel m = null;
            try {
                if (_path.length == 0) return;
                Json.Parser parser = new Json.Parser ();
                parser.load_from_file (_path);
                Json.Node ? node = parser.get_root ();
                if (node == null) {
                    throw new Json.ParserError.PARSE ("Node is null!");
                }

                modify_cb (node);

                ConfigModel model = Json.gobject_deserialize (
                    typeof (ConfigModel), node) as ConfigModel;
                if (model == null) {
                    throw new Json.ParserError.UNKNOWN ("Json model is null!");
                }
                m = model;
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
            _instance = m ?? new ConfigModel ();
            debug (_instance.to_string ());
        }

        /* Properties */

        /** The notifications and controlcenters horizontal alignment */
        public PositionX positionX { get; set; default = PositionX.RIGHT; }
        /** The notifications and controlcenters vertical alignment */
        public PositionY positionY { get; set; default = PositionY.TOP; }

        /** The timeout for notifications with NORMAL priority */
        private const int _timeout_def = 10;
        private int _timeout = _timeout_def;
        public int timeout {
            get {
                return _timeout;
            }
            set {
                _timeout = value < 1 ? _timeout_def : value;
            }
        }

        /** The timeout for notifications with LOW priority */
        private const int _timeout_low_def = 5;
        private int _timeout_low = _timeout_low_def;
        public int timeout_low {
            get {
                return _timeout_low;
            }
            set {
                _timeout_low = value < 1 ? _timeout_low_def : value;
            }
        }

        /** The transition time for all animations */
        private const int _transition_time_def = 200;
        private int _transition_time = _transition_time_def;
        public int transition_time {
            get {
                return _transition_time;
            }
            set {
                _transition_time = value < 0 ? _transition_time_def : value;
            }
        }

        /** The timeout for notifications with CRITICAL priority */
        private const int _timeout_critical_def = 0;
        private int _timeout_critical = _timeout_critical_def;
        public int timeout_critical {
            get {
                return _timeout_critical;
            }
            set {
                _timeout_critical = value < 0 ? _timeout_critical_def : value;
            }
        }

        /*
         * Specifies if the control center should use keyboard shortcuts
         * and block keyboard input for other applications while open
         */
        public bool keyboard_shortcuts { get; set; default = true; }

        /** Specifies if the notification image should be shown or not */
        public ImageVisibility image_visibility {
            get;
            set;
            default = ImageVisibility.ALWAYS;
        }

        /**
         * Notification window's width, in pixels.
         */
        public int notification_window_width { get; set; default = 500; }

        /** Hides the control center after clearing all notifications */
        public bool hide_on_clear { get; set; default = false; }

        /** Hides the control center when clicking on notification action */
        public bool hide_on_action { get; set; default = true; }

        /** GtkLayerShell margins around the notification center */
        private int control_center_margin_top_ = 0;
        public int control_center_margin_top {
            get {
                return control_center_margin_top_;
            }
            set {
                control_center_margin_top_ = value < 0 ? 0 : value;
            }
        }

        private int control_center_margin_bottom_ = 0;
        public int control_center_margin_bottom {
            get {
                return control_center_margin_bottom_;
            }
            set {
                control_center_margin_bottom_ = value < 0 ? 0 : value;
            }
        }

        private int control_center_margin_left_ = 0;
        public int control_center_margin_left {
            get {
                return control_center_margin_left_;
            }
            set {
                control_center_margin_left_ = value < 0 ? 0 : value;
            }
        }

        private int control_center_margin_right_ = 0;
        public int control_center_margin_right {
            get {
                return control_center_margin_right_;
            }
            set {
                control_center_margin_right_ = value < 0 ? 0 : value;
            }
        }

        /** Categories settings */
        public HashTable<string, Category> categories_settings {
            get;
            set;
            default = new HashTable<string, Category>(str_hash, str_equal);
        }

        /** Scripts */
        public HashTable<string, Script> scripts {
            get;
            set;
            default = new HashTable<string, Script>(str_hash, str_equal);
        }

        /* Methods */

        /**
         * Selects the deserialization method based on the property name.
         * Needed to parse those parameters of complex types like hashtables,
         * which are not natively supported by the default deserialization function.
         */
        public override bool deserialize_property (string property_name,
                                                   out Value value,
                                                   ParamSpec pspec,
                                                   Json.Node property_node) {
            switch (property_name) {
                case "categories-settings" :
                    bool status;
                    HashTable<string, Category> result =
                        extract_hashtable<Category>(
                            property_name,
                            property_node,
                            out status);
                    value = result;
                    return status;
                case "scripts":
                    bool status;
                    HashTable<string, Script> result =
                        extract_hashtable<Script>(
                            property_name,
                            property_node,
                            out status);
                    value = result;
                    return status;
                default:
                    // Handles all other properties
                    return default_deserialize_property (
                        property_name, out value, pspec, property_node);
            }
        }

        /**
         * Extracts and returns a GLib.Object from a nested JSON Object
         */
        private HashTable<string, T> extract_hashtable<T>(string property_name,
                                                          Json.Node node,
                                                          out bool status) {
            status = false;
            var tmp_table = new HashTable<string, T>(str_hash, str_equal);

            // Check if T is a descendant of GLib.Object
            assert (typeof (T).is_a (Type.OBJECT));

            if (node.get_node_type () != Json.NodeType.OBJECT) {
                stderr.printf ("Node %s is not a json object!...\n",
                               property_name);
                return tmp_table;
            }

            Json.Object ? root_object = node.get_object ();
            if (root_object == null) return tmp_table;

            foreach (string * member in root_object.get_members ()) {
                Json.Object * object = root_object.get_object_member (member);
                if (object == null) {
                    stderr.printf (
                        "%s category is not a json object, skipping...\n",
                        member);
                    continue;
                }

                // Creates a new GLib.Object with all of the properties of T
                Object obj = Object.new (typeof (T));
                foreach (var name in object->get_members ()) {
                    Value value = object->get_member (name).get_value ();
                    obj.set_property (name, value);
                }

                tmp_table.insert (member, (T) obj);
            }

            status = true;
            return tmp_table;
        }

        private Json.Object serialize_hashtable<T>(HashTable<string, T> table) {
            var obj = new Json.Object ();

            // Check if T is a descendant of GLib.Object
            assert (typeof (T).is_a (Type.OBJECT));

            if (table == null) return obj;

            table.foreach ((key, value) => {
                obj.set_member (key, Json.gobject_serialize (value as Object));
            });
            return obj;
        }

        /**
         * Called when `Json.gobject_serialize (ConfigModel.instance)` is called
         */
        public Json.Node serialize_property (string property_name,
                                             Value value,
                                             ParamSpec pspec) {
            var node = new Json.Node (Json.NodeType.VALUE);
            switch (property_name) {
                case "positionX":
                    node.set_string (((PositionX) value.get_enum ()).parse ());
                    break;
                case "positionY":
                    node.set_string (((PositionY) value.get_enum ()).parse ());
                    break;
                case "image-visibility":
                    var val = ((ImageVisibility) value.get_enum ()).parse ();
                    node.set_string (val);
                    break;
                case "categories-settings":
                    node = new Json.Node (Json.NodeType.OBJECT);
                    var table = (HashTable<string, Category>) value.get_boxed ();
                    node.set_object (serialize_hashtable<Category>(table));
                    break;
                case "scripts":
                    node = new Json.Node (Json.NodeType.OBJECT);
                    var table = (HashTable<string, Script>) value.get_boxed ();
                    node.set_object (serialize_hashtable<Script>(table));
                    break;
                default:
                    node.set_value (value);
                    break;
            }
            return node;
        }

        public string to_string () {
            var json = Json.gobject_serialize (ConfigModel.instance);
            return Json.to_string (json, true);
        }

        /**
         * Changes the `member_name` to the specified value if their types match
         */
        public void change_value (string member_name,
                                  Variant value,
                                  bool write = true,
                                  string ? path = null) {
            reload_config ((node) => {
                unowned Json.Object obj = node.get_object ();
                if (obj == null) return;
                debug ("Config change: %s %s",
                       member_name, value.get_type_string ());
                switch (value.get_type_string ()) {
                        case "i":
                            int val = value.get_int32 ();
                            obj.set_int_member (member_name, val);
                            debug ("Config changed %s", member_name);
                            break;
                        case "s":
                            string val = value.get_string ();
                            obj.set_string_member (member_name, val);
                            debug ("Config changed %s", member_name);
                            break;
                        case "b":
                            bool val = value.get_boolean ();
                            obj.set_boolean_member (member_name, val);
                            debug ("Config changed %s", member_name);
                            break;
                }
            });

            if (!write) {
                debug ("Skipped writing new config to %s", path);
                return;
            }
            if (write_to_file (path)) {
                debug ("Successfully wrote to %s", path);
            } else {
                error ("ERROR WRITING TO %s", path);
            }
        }

        /**
         * Writes and replaces settings with the new settings in `path`. If
         * `path` is "null", the default user accessable config will be used
         * ("~/.config/swaync/config.json")
         */
        private bool write_to_file (owned string ? path = null) {
            try {
                if (path == null) {
                    // Use the default user accessable config
                    string dir_path = Path.build_path (
                        Path.DIR_SEPARATOR.to_string (),
                        Environment.get_user_config_dir (),
                        "swaync");
                    path = Path.build_path (Path.DIR_SEPARATOR.to_string (),
                                            dir_path, "config.json");
                    var dir = File.new_for_path (dir_path);
                    if (!dir.query_exists ()) {
                        dir.make_directory ();
                    }
                    var file = File.new_for_path (path);
                    if (!file.query_exists ()) {
                        file.create (FileCreateFlags.NONE);
                    }
                }

                var file = File.new_for_path (path);

                string data = ConfigModel.instance.to_string ();
                return file.replace_contents (
                    data.data,
                    null,
                    false,
                    FileCreateFlags.REPLACE_DESTINATION,
                    null);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                return false;
            }
        }
    }
}
