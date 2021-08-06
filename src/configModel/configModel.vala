namespace SwayNotificatonCenter {
    private errordomain JSONError {
        INVALID_FORMAT,
        INVALID_VALUE
    }

    public struct ConfigModel {
        Positions positionX { get; set; }
        Positions positionY { get; set; }

        public ConfigModel (Json.Node ? node) {
            try {
                if (node.get_node_type () != Json.NodeType.OBJECT) {
                    throw new JSONError.INVALID_FORMAT (
                              @"JSON DOES NOT CONTAIN OBJECT!");
                }
                Json.Object obj = node.get_object ();

                positionX = Positions.from_string (assert_node (obj, "positionX", { "left", "right" }).get_string ());
                positionY = Positions.from_string (assert_node (obj, "positionY", { "top", "bottom" }).get_string ());
            } catch (JSONError e) {
                stderr.printf (e.message + "\n");
                Process.exit (1);
            }
        }

        private Json.Node ? assert_node (Json.Object ? obj,
                                         string name,
                                         string[] correct_values) throws JSONError {
            Json.Node? node = obj.get_member (name);
            if (node == null || node.get_node_type () != Json.NodeType.VALUE) {
                throw new JSONError.INVALID_FORMAT (
                          @"JSON value $(name) wasn't defined!");
            }
            if (correct_values.length > 0 &&
                !(node.get_value ().get_string () in correct_values)) {
                throw new JSONError.INVALID_VALUE (
                          @"JSON value $(name) does not contain a correct value!");
            }
            return node;
        }
    }

    public enum Positions {
        left, right, top, bottom;

        public static Positions from_string (string str) {
            EnumClass enumc = (EnumClass) typeof (Positions).class_ref ();
            unowned EnumValue ? eval = enumc.get_value_by_nick (str);
            return (Positions) eval.value;
        }

        public string parse () {
            EnumClass enumc = (EnumClass) typeof (Positions).class_ref ();
            return enumc.get_value_by_name (this.to_string ()).value_nick;
        }
    }
}
