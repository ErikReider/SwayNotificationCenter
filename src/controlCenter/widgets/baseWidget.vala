namespace SwayNotificationCenter.Widgets {
    public interface BaseWidget {
        public abstract string key { get; }

        protected Json.Object ? get_config (Gtk.Widget widget) {
            unowned HashTable<string, Json.Object> config
                = ConfigModel.instance.widget_config;
            string ? orig_key = null;
            Json.Object ? props = null;
            bool result = config.lookup_extended (key, out orig_key, out props);
            if (!result || orig_key == null || props == null) {
                critical ("%s: Config not found!\n", key.up ());
                return null;
            }
            return props;
        }

        protected void get_prop<T> (Json.Object config, string value_key, ref T value) {
            if (!config.has_member (value_key)) {
                warning ("%s: Config doesn't have key: %s!\n", key.up (), value_key);
                return;
            }
            var member = config.get_member (value_key);

            Type base_type = Functions.get_base_type (member.get_value_type ());

            Type generic_base_type = Functions.get_base_type (typeof (T));
            // Convert all INTs to INT64
            if (generic_base_type == Type.INT) generic_base_type = Type.INT64;

            if (!base_type.is_a (generic_base_type)) {
                warning ("%s: Config type %s doesn't match: %s!\n",
                         key.up (),
                         typeof (T).name (),
                         member.get_value_type ().name ());
                return;
            }
            switch (typeof (T)) {
                case Type.STRING:
                    value = member.get_string ();
                    break;
                case Type.INT:
                case Type.INT64:
                    value = member.get_int ();
                    break;
                case Type.BOOLEAN:
                    value = member.get_boolean ();
                    break;
            }
            return;
        }
    }
}
