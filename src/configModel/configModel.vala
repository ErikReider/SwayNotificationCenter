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
        public PositionX positionX { get; set; default = PositionX.RIGHT; }
        public PositionY positionY { get; set; default = PositionY.TOP; }
        public uint timeout { get; set; default = 10; }
        public uint timeout_low { get; set; default = 5; }

        public static ConfigModel from_path (string path) {
            try {
                if (path.length == 0) return new ConfigModel ();
                Json.Parser parser = new Json.Parser ();
                parser.load_from_file (path);
                var node = parser.get_root ();
                ConfigModel model = Json.gobject_deserialize (typeof (ConfigModel), node) as ConfigModel;
                if (model == null) {
                    throw new Json.ParserError.UNKNOWN ("Json model is null!");
                }
                return model;
            } catch (Error e) {
                stderr.printf (e.message + "\n");
                return new ConfigModel ();
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
