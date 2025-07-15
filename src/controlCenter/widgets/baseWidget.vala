namespace SwayNotificationCenter.Widgets {
    public abstract class BaseWidget : Gtk.Box {
        public abstract string widget_name { get; }

        public weak string css_class_name {
            owned get {
                return "widget-%s".printf (widget_name);
            }
        }

        public string key { get; private set; }
        public string suffix { get; private set; }

        public unowned SwayncDaemon swaync_daemon;
        public unowned NotiDaemon noti_daemon;

        public enum ButtonType {
            TOGGLE,
            NORMAL;

            public static ButtonType parse (string value) {
              switch (value) {
                case "toggle":
                  return ButtonType.TOGGLE;
                default:
                  return ButtonType.NORMAL;
              }
            }
        }

        protected BaseWidget (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            this.suffix = suffix;
            this.key = widget_name + (suffix.length > 0 ? "#%s".printf (suffix) : "");
            this.swaync_daemon = swaync_daemon;
            this.noti_daemon = noti_daemon;

            set_overflow (Gtk.Overflow.HIDDEN);
            add_css_class ("widget");
            add_css_class (css_class_name);
            if (suffix.length > 0) add_css_class (suffix);
        }

        protected Json.Object ? get_config (Gtk.Widget widget) {
            unowned OrderedHashTable<Json.Object> config
                = ConfigModel.instance.widget_config;
            string ? orig_key = null;
            Json.Object ? props = null;
            bool result = config.lookup_extended (key, out orig_key, out props);
            if (!result || orig_key == null || props == null) {
                critical ("%s: Config not found! Using default config...\n", key);
                return null;
            }
            return props;
        }

        public virtual void on_cc_visibility_change (bool value) {}

        protected T ? get_prop<T> (Json.Object config, string value_key, out bool found = null) {
            found = false;
            if (!config.has_member (value_key)) {
                debug ("%s: Config doesn't have key: %s!\n", key, value_key);
                return null;
            }
            var member = config.get_member (value_key);

            Type base_type = Functions.get_base_type (member.get_value_type ());

            Type generic_base_type = Functions.get_base_type (typeof (T));
            // Convert all INTs to INT64
            if (generic_base_type == Type.INT) generic_base_type = Type.INT64;

            if (!base_type.is_a (generic_base_type)) {
                warning ("%s: Config type %s doesn't match: %s!\n",
                         key,
                         typeof (T).name (),
                         member.get_value_type ().name ());
                return null;
            }
            found = true;
            switch (generic_base_type) {
                case Type.STRING:
                    return member.get_string ();
                case Type.INT64:
                    return (int) member.get_int ();
                case Type.BOOLEAN:
                    return member.get_boolean ();
                default:
                    found = false;
                    return null;
            }
        }

        protected Json.Array ? get_prop_array (Json.Object config, string value_key) {
            if (!config.has_member (value_key)) {
                debug ("%s: Config doesn't have key: %s!\n", key, value_key);
                return null;
            }
            var member = config.get_member (value_key);
            if (member.get_node_type () != Json.NodeType.ARRAY) {
                debug ("Unable to find Json Array for member %s", value_key);
            }
            return config.get_array_member (value_key);
        }

        protected Action[] parse_actions (Json.Array actions) {
            Action[] res = new Action[actions.get_length ()];
            for (int i = 0; i < actions.get_length (); i++) {
                string label = actions.get_object_element (i).get_string_member_with_default ("label", "label");
                string command = actions.get_object_element (i).get_string_member_with_default ("command", "");
                string t = actions.get_object_element (i).get_string_member_with_default ("type", "normal");
                ButtonType type = ButtonType.parse (t);
                string update_command =
                    actions.get_object_element (i).get_string_member_with_default ("update-command", "");
                bool active = actions.get_object_element (i).get_boolean_member_with_default ("active", false);
                res[i] = Action () {
                    label = label,
                    command = command,
                    type = type,
                    update_command = update_command,
                    active = active
                };
            }
            return res;
        }


        protected async void execute_command (string cmd, string[] env_additions = {}) {
            string msg = "";
            yield Functions.execute_command (cmd, env_additions, out msg);
        }
    }
}
