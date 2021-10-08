namespace SwayNotificatonCenter {
    public enum PositionX {
        RIGHT, LEFT;

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

    public class ConfigModel : Object, Json.Serializable {

        private static ConfigModel _instance;
        private static string _path = "";

        /** Get the static singleton */
        public static unowned ConfigModel instance {
            get {
                if (_instance == null) _instance = new ConfigModel ();
                if (_path.length <= 0) _path = Functions.get_config_path ();
                return _instance;
            }
        }

        /** Get the static singleton and reload the config */
        public static unowned ConfigModel init (string path) {
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

                ConfigModel model = Json.gobject_deserialize (typeof (ConfigModel), node) as ConfigModel;
                if (model == null) {
                    throw new Json.ParserError.UNKNOWN ("Json model is null!");
                }
                m = model;
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
            _instance = m ?? new ConfigModel ();
            debug (_instance.json_serialized ());
        }

        public PositionX positionX { get; set; default = PositionX.RIGHT; }
        public PositionY positionY { get; set; default = PositionY.TOP; }

        private const int _timeout_def = 10;
        private int _timeout = _timeout_def;
        public int timeout {
            get {
                return _timeout;
            } set {
                _timeout = value < 1 ? _timeout_def : value;
            }
        }

        private const int _timeout_low_def = 5;
        private int _timeout_low = _timeout_low_def;
        public int timeout_low {
            get {
                return _timeout_low;
            } set {
                _timeout_low = value < 1 ? _timeout_low_def : value;
            }
        }

        public Json.Node serialize_property (string property_name,
                                             Value value,
                                             ParamSpec pspec) {
            var node = new Json.Node (Json.NodeType.VALUE);
            switch (property_name) {
                case "positionX" :
                    node.set_string (((PositionX) value.get_enum ()).parse ());
                    break;
                case "positionY":
                    node.set_string (((PositionY) value.get_enum ()).parse ());
                    break;
                default:
                    node.set_value (value);
                    break;
            }
            return node;
        }

        public string json_serialized () {
            var json = Json.gobject_serialize (_instance);
            return Json.to_string (json, true);
        }

        public void change_value (string path,
                                  string member_name,
                                  Variant value) {
            reload_config ((node) => {
                unowned Json.Object obj = node.get_object ();
                if (obj == null) return;
                debug ("Config change: %s %s",
                       member_name, value.get_type_string ());
                switch (value.get_type_string ()) {
                    case "i":
                        int val = value.get_int32 ();
                        obj.set_int_member (member_name, val);
                        break;
                    case "s":
                        string val = value.get_string ();
                        obj.set_string_member (member_name, val);
                        break;
                    case "b":
                        bool val = value.get_boolean ();
                        obj.set_boolean_member (member_name, val);
                        break;
                }
            });
        }
    }
}
