namespace SwayNotificationCenter {
    public enum PositionX {
        RIGHT, LEFT, CENTER, NONE;
    }

    public enum PositionY {
        TOP, BOTTOM, NONE;
    }

    public enum ImageVisibility {
        ALWAYS, WHEN_AVAILABLE, NEVER;

        public string parse () {
            switch (this) {
                default:
                    return "always";
                case WHEN_AVAILABLE:
                    return "when_available";
                case NEVER:
                    return "never";
            }
        }
    }

    public enum Layer {
        BACKGROUND, BOTTOM, TOP, OVERLAY;

        public string parse () {
            switch (this) {
                default:
                    return "top";
                case BACKGROUND:
                    return "background";
                case BOTTOM:
                    return "bottom";
                case TOP:
                    return "top";
                case OVERLAY:
                    return "overlay";
            }
        }
    }

    public enum CssPriority {
        APPLICATION, USER;

        public int get_priority () {
            switch (this) {
                case APPLICATION:
                default:
                    return Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION;
                case USER:
                    return Gtk.STYLE_PROVIDER_PRIORITY_USER;
            }
        }
    }

    public class Category : Object {
        public string ? sound { get; set; default = null; }
        public string ? icon { get; set; default = null; }

        public string to_string () {
            string[] fields = {};
            if (sound != null) fields += "sound: %s".printf (sound);
            if (icon != null) fields += "icon: %s".printf (icon);
            return string.joinv (", ", fields);
        }
    }

    public class NotificationMatching : Object, Json.Serializable {
        public string ? app_name { get; set; default = null; }
        public string ? summary { get; set; default = null; }
        public string ? body { get; set; default = null; }
        public string ? urgency { get; set; default = null; }
        public string ? category { get; set; default = null; }

        public virtual bool matches_notification (NotifyParams param) {
            if (app_name != null) {
                if (param.app_name == null) return false;
                bool result = Regex.match_simple (
                    app_name, param.app_name,
                    0,
                    RegexMatchFlags.NOTEMPTY);
                if (!result) return false;
            }
            if (summary != null) {
                if (param.summary == null) return false;
                bool result = Regex.match_simple (
                    summary, param.summary,
                    0,
                    RegexMatchFlags.NOTEMPTY);
                if (!result) return false;
            }
            if (body != null) {
                if (param.body == null) return false;
                bool result = Regex.match_simple (
                    body, param.body,
                    0,
                    RegexMatchFlags.NOTEMPTY);
                if (!result) return false;
            }
            if (urgency != null) {
                bool result = Regex.match_simple (
                    urgency, param.urgency.to_string (),
                    0,
                    RegexMatchFlags.NOTEMPTY);
                if (!result) return false;
            }
            if (category != null) {
                if (param.category == null) return false;
                bool result = Regex.match_simple (
                    category, param.category,
                    0,
                    RegexMatchFlags.NOTEMPTY);
                if (!result) return false;
            }
            return true;
        }

        public string to_string () {
            string[] fields = {};
            if (app_name != null) fields += "app-name: %s".printf (app_name);
            if (summary != null) fields += "summary: %s".printf (summary);
            if (body != null) fields += "body: %s".printf (body);
            if (urgency != null) fields += "urgency: %s".printf (urgency);
            if (category != null) fields += "category: %s".printf (category);
            return string.joinv (", ", fields);
        }

        public override Json.Node serialize_property (string property_name,
                                                      Value value,
                                                      ParamSpec pspec) {
            // Return enum nickname instead of enum int value
            if (value.type ().is_a (Type.ENUM)) {
                var node = new Json.Node (Json.NodeType.VALUE);
                EnumClass enumc = (EnumClass) value.type ().class_ref ();
                unowned EnumValue ? eval
                    = enumc.get_value (value.get_enum ());
                if (eval == null) {
                    node.set_value (value);
                    return node;
                }
                node.set_string (eval.value_nick);
                return node;
            }
            return default_serialize_property (property_name, value, pspec);
        }
    }

    public enum NotificationStatusEnum {
        ENABLED,
        MUTED,
        IGNORED,
        TRANSIENT;

        public string to_string () {
            switch (this) {
                default :
                    return "enabled";
                case MUTED:
                    return "muted";
                case IGNORED:
                    return "ignored";
                case TRANSIENT:
                    return "transient";
            }
        }

        public static NotificationStatusEnum from_value (string value) {
            switch (value) {
                default:
                    return ENABLED;
                case "muted":
                    return MUTED;
                case "ignored":
                    return IGNORED;
                case "transient":
                    return TRANSIENT;
            }
        }
    }

    public enum NotificationUrgencyEnum {
        UNSET = -1,
        LOW = UrgencyLevels.LOW,
        NORMAL = UrgencyLevels.NORMAL,
        CRITICAL = UrgencyLevels.CRITICAL;

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
                default:
                    return "Unset";
            }
        }
    }

    public class NotificationVisibility : NotificationMatching {
        public NotificationStatusEnum state { get; set; }
        public NotificationUrgencyEnum override_urgency {
            get; set; default = NotificationUrgencyEnum.UNSET;
        }
    }

    public enum ScriptRunOnType {
        ACTION,
        RECEIVE;
    }

#if WANT_SCRIPTING
    public class Script : NotificationMatching {
        public string ? exec { get; set; default = null; }
        public ScriptRunOnType run_on { get; set; default = ScriptRunOnType.RECEIVE; }

        public async bool run_script (NotifyParams param, out string msg) {
            msg = "";
            try {
                string[] spawn_env = Environ.get ();
                // Export env variables
                spawn_env += "SWAYNC_APP_NAME=%s".printf (param.app_name);
                spawn_env += "SWAYNC_SUMMARY=%s".printf (param.summary);
                spawn_env += "SWAYNC_BODY=%s".printf (param.body);
                spawn_env += "SWAYNC_URGENCY=%s".printf (param.urgency.to_string ());
                spawn_env += "SWAYNC_CATEGORY=%s".printf (param.category);
                spawn_env += "SWAYNC_ID=%s".printf (param.applied_id.to_string ());
                spawn_env += "SWAYNC_REPLACES_ID=%s".printf (param.replaces_id.to_string ());
                spawn_env += "SWAYNC_TIME=%s".printf (param.time.to_string ());
                spawn_env += "SWAYNC_DESKTOP_ENTRY=%s".printf (param.desktop_entry ?? "");

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
                msg = e.message;
                return false;
            }
        }

        public override bool matches_notification (NotifyParams param) {
            if (exec == null) return false;
            return base.matches_notification (param);
        }
    }
#endif

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
        public PositionX positionX { // vala-lint=naming-convention
            get; set; default = PositionX.RIGHT;
        }
        /** The notifications and controlcenters vertical alignment */
        public PositionY positionY { // vala-lint=naming-convention
            get; set; default = PositionY.TOP;
        }

        /** Layer of control center */
        public Layer layer {
            get; set; default = Layer.TOP;
        }

        /** The CSS loading priority */
        public CssPriority cssPriority { // vala-lint=naming-convention
            get; set; default = CssPriority.APPLICATION;
        }

        /** The timeout for notifications with NORMAL priority */
        private const int TIMEOUT_DEFAULT = 10;
        private int _timeout = TIMEOUT_DEFAULT;
        public int timeout {
            get {
                return _timeout;
            }
            set {
                _timeout = value < 0 ? TIMEOUT_DEFAULT : value;
            }
        }

        /** The timeout for notifications with LOW priority */
        private const int TIMEOUT_LOW_DEFAULT = 5;
        private int _timeout_low = TIMEOUT_LOW_DEFAULT;
        public int timeout_low {
            get {
                return _timeout_low;
            }
            set {
                _timeout_low = value < 0 ? TIMEOUT_LOW_DEFAULT : value;
            }
        }

        /** The timeout for notifications with CRITICAL priority */
        private const int TIMEOUT_CRITICAL_DEFAULT = 0;
        private int _timeout_critical = TIMEOUT_CRITICAL_DEFAULT;
        public int timeout_critical {
            get {
                return _timeout_critical;
            }
            set {
                _timeout_critical = value < 0 ? TIMEOUT_CRITICAL_DEFAULT : value;
            }
        }

        /** The transition time for all animations */
        private const int TRANSITION_TIME_DEFAULT = 200;
        private int _transition_time = TRANSITION_TIME_DEFAULT;
        public int transition_time {
            get {
                return _transition_time;
            }
            set {
                _transition_time = value < 0 ? TRANSITION_TIME_DEFAULT : value;
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
            default = ImageVisibility.WHEN_AVAILABLE;
        }

        /**
         * Notification window's width, in pixels.
         */
        public int notification_window_width { get; set; default = 500; }

        /** Hides the control center after clearing all notifications */
        public bool hide_on_clear { get; set; default = false; }

        /** Hides the control center when clicking on notification action */
        public bool hide_on_action { get; set; default = true; }

        /** The controlcenters horizontal alignment. Supersedes `positionX` if not `NONE` */
        public PositionX control_center_positionX { // vala-lint=naming-convention
            get; set; default = PositionX.NONE;
        }
        /** The controlcenters vertical alignment. Supersedes `positionY` if not `NONE` */
        public PositionY control_center_positionY { // vala-lint=naming-convention
            get; set; default = PositionY.NONE;
        }

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
            default = new HashTable<string, Category> (str_hash, str_equal);
        }

        /** Notification Status */
        public HashTable<string, NotificationVisibility> notification_visibility {
            get;
            set;
            default = new HashTable<string, NotificationVisibility> (str_hash, str_equal);
        }

#if WANT_SCRIPTING
        /** Scripts */
        public HashTable<string, Script> scripts {
            get;
            set;
            default = new HashTable<string, Script> (str_hash, str_equal);
        }
        /** Show notification if script fails */
        public bool script_fail_notify { get; set; default = true; }
#endif

        /** Whether to expand the notification center across both edges of the screen */
        public bool fit_to_screen { get; set; default = true; }

        /**
         * Notification center's height, in pixels.
         * Set `fit_to_screen` to true to ignore the height setting.
         */
        private const int CONTROL_CENTER_MINIMUM_HEIGHT = 300;
        private const int CONTROL_CENTER_DEFAULT_HEIGHT = 300;
        private int _control_center_height = CONTROL_CENTER_DEFAULT_HEIGHT;
        public int control_center_height {
            get {
                return _control_center_height;
            }
            set {
                _control_center_height = value > CONTROL_CENTER_MINIMUM_HEIGHT
                    ? value : CONTROL_CENTER_MINIMUM_HEIGHT;
            }
        }

        /**
         * Notification center's width, in pixels.
         */
        private const int CONTROL_CENTER_MINIMUM_WIDTH = 300;
        private const int CONTROL_CENTER_DEFAULT_WIDTH = 500;
        private int _control_center_width = CONTROL_CENTER_DEFAULT_WIDTH;
        public int control_center_width {
            get {
                return _control_center_width;
            }
            set {
                _control_center_width = value > CONTROL_CENTER_MINIMUM_WIDTH
                    ? value : CONTROL_CENTER_MINIMUM_WIDTH;
            }
        }

        /**
         * Notification icon size, in pixels.
         */
        private const int NOTIFICATION_ICON_MINIMUM_SIZE = 16;
        private const int NOTIFICATION_ICON_DEFAULT_SIZE = 64;
        private int _notification_icon_size = NOTIFICATION_ICON_DEFAULT_SIZE;
        public int notification_icon_size {
            get {
                return _notification_icon_size;
            }
            set {
                _notification_icon_size = value > NOTIFICATION_ICON_MINIMUM_SIZE
                    ? value : NOTIFICATION_ICON_MINIMUM_SIZE;
            }
        }

        /**
         * Notification body image height, in pixels.
         */
        private const int NOTIFICATION_BODY_IMAGE_MINIMUM_HEIGHT = 100;
        private const int NOTIFICATION_BODY_IMAGE_DEFAULT_HEIGHT = 100;
        private int _notification_body_image_height = NOTIFICATION_BODY_IMAGE_DEFAULT_HEIGHT;
        public int notification_body_image_height {
            get {
                return _notification_body_image_height;
            }
            set {
                _notification_body_image_height =
                    value > NOTIFICATION_BODY_IMAGE_MINIMUM_HEIGHT
                    ? value : NOTIFICATION_BODY_IMAGE_MINIMUM_HEIGHT;
            }
        }

        /**
         * Notification body image width, in pixels.
         */
        private const int NOTIFICATION_BODY_IMAGE_MINIMUM_WIDTH = 200;
        private const int NOTIFICATION_BODY_IMAGE_DEFAULT_WIDTH = 200;
        private int _notification_body_image_width = NOTIFICATION_BODY_IMAGE_DEFAULT_WIDTH;
        public int notification_body_image_width {
            get {
                return _notification_body_image_width;
            }
            set {
                _notification_body_image_width =
                    value > NOTIFICATION_BODY_IMAGE_MINIMUM_WIDTH
                    ? value : NOTIFICATION_BODY_IMAGE_MINIMUM_WIDTH;
            }
        }

        /** Widgets to show in ControlCenter */
        public GenericArray<string> widgets {
            get;
            set;
            default = new GenericArray<string> ();
        }

        /** Widgets to show in ControlCenter */
        public HashTable<string, Json.Object> widget_config {
            get;
            set;
            default = new HashTable<string, Json.Object> (str_hash, str_equal);
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
                        extract_hashtable<Category> (
                            property_name,
                            property_node,
                            out status);
                    value = result;
                    return status;
                case "notification-visibility":
                    bool status;
                    HashTable<string, NotificationVisibility> result =
                        extract_hashtable<NotificationVisibility> (
                            property_name,
                            property_node,
                            out status);
                    value = result;
                    return status;
#if WANT_SCRIPTING
                case "scripts":
                    bool status;
                    HashTable<string, Script> result =
                        extract_hashtable<Script> (
                            property_name,
                            property_node,
                            out status);
                    value = result;
                    return status;
#endif
                case "widgets":
                    bool status;
                    GenericArray<string> result =
                        extract_array<string> (property_name,
                                               property_node,
                                               out status);
                    value = result;
                    return status;
                case "widget-config":
                    HashTable<string, Json.Object> result
                        = new HashTable<string, Json.Object> (str_hash, str_equal);
                    if (property_node.get_value_type ().name () != "JsonObject") {
                        value = result;
                        return true;
                    }
                    Json.Object obj = property_node.get_object ();
                    if (obj.get_size () == 0) {
                        value = result;
                        return true;
                    }
                    foreach (var key in obj.get_members ()) {
                        Json.Node ? node = obj.get_member (key);
                        if (node.get_node_type () != Json.NodeType.OBJECT) continue;
                        Json.Object ? o = node.get_object ();
                        if (o != null) result.set (key, o);
                    }
                    value = result;
                    return true;
                default:
                    // Handles all other properties
                    return default_deserialize_property (
                        property_name, out value, pspec, property_node);
            }
        }

        /**
         * Called when `Json.gobject_serialize (ConfigModel.instance)` is called
         */
        public Json.Node serialize_property (string property_name,
                                             Value value,
                                             ParamSpec pspec) {
            var node = new Json.Node (Json.NodeType.VALUE);
            if (value.type ().is_a (Type.ENUM)) {
                EnumClass enumc = (EnumClass) pspec.value_type.class_ref ();
                EnumValue ? eval
                    = enumc.get_value (value.get_enum ());
                if (eval == null) {
                    node.set_value (value);
                    return node;
                }
                node.set_string (eval.value_nick);
                return node;
            }
            // All other properties that can't be serialized
            switch (property_name) {
                case "categories-settings" :
                    node = new Json.Node (Json.NodeType.OBJECT);
                    var table = (HashTable<string, Category>) value.get_boxed ();
                    node.set_object (serialize_hashtable<Category> (table));
                    break;
                case "notification-visibility":
                    node = new Json.Node (Json.NodeType.OBJECT);
                    var table = (HashTable<string, NotificationVisibility>) value.get_boxed ();
                    node.set_object (serialize_hashtable<NotificationVisibility> (table));
                    break;
#if WANT_SCRIPTING
                case "scripts":
                    node = new Json.Node (Json.NodeType.OBJECT);
                    var table = (HashTable<string, Script>) value.get_boxed ();
                    node.set_object (serialize_hashtable<Script> (table));
                    break;
#endif
                case "widgets":
                    node = new Json.Node (Json.NodeType.ARRAY);
                    var table = (GenericArray<string>) value.get_boxed ();
                    node.set_array (serialize_array<string> (table));
                    break;
                case "widget-config":
                    node = new Json.Node (Json.NodeType.OBJECT);
                    var table = (HashTable<string, Json.Object>) value.get_boxed ();
                    node.set_object (serialize_hashtable<Json.Object> (table));
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
         * Extracts and returns a HashTable<string, GLib.Object>
         * from a nested JSON Object.
         *
         * Can only accept these types:
         * - string
         * - bool
         * - int64
         * - GLib.Object
         */
        private HashTable<string, T> extract_hashtable<T> (string property_name,
                                                           Json.Node node,
                                                           out bool status) {
            status = false;
            var tmp_table = new HashTable<string, T> (str_hash, str_equal);

            if (node.get_node_type () != Json.NodeType.OBJECT) {
                stderr.printf ("Node %s is not a json object!...\n",
                               property_name);
                return tmp_table;
            }

            Json.Object ? root_object = node.get_object ();
            if (root_object == null) return tmp_table;

            Type generic_type = Functions.get_base_type (typeof (T));
            foreach (string * key in root_object.get_members ()) {
                unowned Json.Node ? member = root_object.get_member (key);
                if (member == null) continue;

                if (!member.get_value_type ().is_a (generic_type)
                    && !member.get_value_type ().is_a (typeof (Json.Object))) {
                    continue;
                }

                switch (generic_type) {
                    case Type.STRING:
                        unowned string ? str = member.get_string ();
                        if (str != null) tmp_table.insert (key, str);
                        break;
                    case Type.BOOLEAN :
                        tmp_table.insert (key, member.get_boolean ());
                        break;
                    case Type.INT64:
                        tmp_table.insert (key, (int64 ? ) member.get_int ());
                        break;
                    case Type.OBJECT:
                        if (!typeof (T).is_a (Type.OBJECT)) break;

                        unowned Json.Object ? object =
                            root_object.get_object_member (key);
                        if (object == null) break;

                        // Creates a new GLib.Object with all of the properties of T
                        Type type = typeof (T);
                        ObjectClass ocl = (ObjectClass) type.class_ref ();
                        Object obj = Object.new (type);
                        foreach (var name in object.get_members ()) {
                            Value value = object.get_member (name).get_value ();

                            unowned ParamSpec value_spec = null;
                            foreach (var spec in ocl.list_properties ()) {
                                if (spec.name == name) {
                                    value_spec = spec;
                                    break;
                                }
                            }
                            if (value_spec == null) continue;

                            unowned Type spec_type = value_spec.value_type;
                            unowned Type val_type = value.type ();
                            if (spec_type.is_a (val_type)) {
                                // Both are the same type
                                obj.set_property (name, value);
                            } else if (spec_type.is_a (Type.ENUM)
                                       && val_type.is_a (Type.STRING)) {
                                // Set enum from string
                                EnumClass enumc = (EnumClass) spec_type.class_ref ();
                                EnumValue ? eval
                                    = enumc.get_value_by_nick (value.get_string ());
                                if (eval != null) {
                                    obj.set_property (name, eval.value);
                                }
                            }
                        }

                        tmp_table.insert (key, (T) obj);
                        break;
                }
            }

            status = true;
            return tmp_table;
        }

        private Json.Object serialize_hashtable<T> (HashTable<string, T> table) {
            var json_object = new Json.Object ();

            if (table == null) return json_object;

            foreach (string * key in table.get_keys ()) {
                unowned T item = table.get (key);
                if (item == null) continue;

                Type generic_type = Functions.get_base_type (typeof (T));
                switch (generic_type) {
                    case Type.STRING:
                        string ? casted = (string) item;
                        if (casted != null) {
                            json_object.set_string_member (key, casted);
                        }
                        break;
                    case Type.BOOLEAN :
                        bool ? casted = (bool) item;
                        if (casted != null) {
                            json_object.set_boolean_member (key, casted);
                        }
                        break;
                    case Type.INT64 :
                        int64 ? casted = (int64 ? ) item;
                        if (casted != null) {
                            json_object.set_int_member (key, casted);
                        }
                        break;
                    case Type.OBJECT:
                        var node = Json.gobject_serialize (item as Object);
                        json_object.set_member (key, node);
                        break;
                    case Type.BOXED:
                        switch (typeof (T).name ()) {
                            case "JsonObject":
                                json_object.set_object_member (key,
                                                               (Json.Object) item);
                                break;
                            case "JsonArray":
                                json_object.set_array_member (key,
                                                              (Json.Array) item);
                                break;
                        }
                        break;
                }
            }
            return json_object;
        }

        /**
         * Extracts a JSON array and returns a GLib.GenericArray<T>
         *
         * Can only accept these types:
         * - string
         * - bool
         * - int64
         * - GLib.Object
         */
        private GenericArray<T> extract_array<T> (string property_name,
                                                  Json.Node node,
                                                  out bool status) {
            status = false;
            GenericArray<T> tmp_array = new GenericArray<T> ();

            if (node.get_node_type () != Json.NodeType.ARRAY) {
                stderr.printf ("Node %s is not a json array!...\n",
                               property_name);
                return tmp_array;
            }

            Json.Array ? root_array = node.get_array ();
            if (root_array == null) return tmp_array;

            foreach (Json.Node * member in root_array.get_elements ()) {
                Type generic_type = Functions.get_base_type (typeof (T));
                if (!member->get_value_type ().is_a (generic_type)
                    && !member->get_value_type ().is_a (typeof (Json.Object))) {
                    continue;
                }

                switch (generic_type) {
                    case Type.STRING:
                        unowned string ? str = member->get_string ();
                        if (str != null) tmp_array.add (str);
                        break;
                    case Type.BOOLEAN :
                        tmp_array.add (member->get_boolean ());
                        break;
                    case Type.INT64:
                        tmp_array.add (member->get_int ());
                        break;
                    case Type.OBJECT:
                        if (!typeof (T).is_a (Type.OBJECT)) break;

                        unowned Json.Object ? object = member->get_object ();
                        if (object == null) break;

                        // Creates a new GLib.Object with all of the properties of T
                        Object obj = Object.new (typeof (T));
                        foreach (var name in object.get_members ()) {
                            Value value = object.get_member (name).get_value ();
                            obj.set_property (name, value);
                        }

                        tmp_array.add ((T) obj);
                        break;
                }
            }

            status = true;
            return tmp_array;
        }

        private Json.Array serialize_array<T> (GenericArray<T> array) {
            var json_array = new Json.Array ();

            if (array == null) return json_array;

            foreach (T item in array.data) {
                if (item == null) continue;
                Type generic_type = Functions.get_base_type (typeof (T));
                switch (generic_type) {
                    case Type.STRING :
                        string ? casted = (string) item;
                        if (casted != null) {
                            json_array.add_string_element (casted);
                        }
                        break;
                    case Type.BOOLEAN :
                        bool ? casted = (bool) item;
                        if (casted != null) {
                            json_array.add_boolean_element (casted);
                        }
                        break;
                    case Type.INT64 :
                        int64 ? casted = (int64) item;
                        if (casted != null) {
                            json_array.add_int_element (casted);
                        }
                        break;
                    case Type.OBJECT :
                        var node = Json.gobject_serialize (item as Object);
                        json_array.add_element (node);
                        break;
                }
            }
            return json_array;
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
         * `path` is "null", the default user accessible config will be used
         * ("~/.config/swaync/config.json")
         */
        private bool write_to_file (owned string ? path = null) {
            try {
                if (path == null) {
                    // Use the default user accessible config
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
