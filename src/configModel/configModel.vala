namespace SwayNotificatonCenter {
    private errordomain JSONError {
        INVALID_FORMAT,
        INVALID_VALUE
    }

    public enum PositionX {
        RIGHT, LEFT;

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (PositionX).class_ref ();
            return enumc.get_value_by_name (this.parse ()).value_nick;
        }
    }

    public enum PositionY {
        TOP, BOTTOM;

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (PositionY).class_ref ();
            return enumc.get_value_by_name (this.parse ()).value_nick;
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

        public static void reload_config () {
            ConfigModel m = new ConfigModel ();
            try {
                if (_path.length == 0) return;
                Json.Parser parser = new Json.Parser ();
                parser.load_from_file (_path);
                var node = parser.get_root ();
                ConfigModel model = Json.gobject_deserialize (typeof (ConfigModel), node) as ConfigModel;
                if (model == null) {
                    throw new Json.ParserError.UNKNOWN ("Json model is null!");
                }
                m = model;
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
            _instance = m;
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
                case "positionX":
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
            var json = Json.gobject_serialize (this);
            string json_string = Json.to_string (json, true);
            return json_string;
        }
    }
}
