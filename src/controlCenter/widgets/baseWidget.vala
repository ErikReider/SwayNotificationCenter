using Posix;

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

        protected BaseWidget (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            this.suffix = suffix;
            this.key = widget_name + (suffix.length > 0 ? "#%s".printf (suffix) : "");
            this.swaync_daemon = swaync_daemon;
            this.noti_daemon = noti_daemon;

            get_style_context ().add_class (css_class_name);
            if (suffix.length > 0) get_style_context ().add_class (suffix);
        }

        protected Json.Object ? get_config (Gtk.Widget widget) {
            unowned HashTable<string, Json.Object> config
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

        protected T? get_prop<T> (Json.Object config, string value_key) {
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
            switch (generic_base_type) {
                case Type.STRING:
                    return member.get_string ();
                case Type.INT64:
                    return (int) member.get_int ();
                case Type.BOOLEAN:
                    return member.get_boolean ();
                default:
                    return null;
            }
        }

        protected Json.Array? get_prop_array (Json.Object config, string value_key){
            if(!config.has_member (value_key)){
                debug ("%s: Config doesn't have key: %s!\n", key, value_key);
                return null;
            }

            return config.get_array_member (value_key);
        }

        protected void execute_command (string cmd){
            pid_t pid;
            int status;

            if((pid = fork())<0){
                perror ("fork()");
            }

            if(pid==0){ // Child process
                execl ("/bin/sh", "sh", "-c", cmd);
            }

            waitpid (pid, out status, 1);
        }
    }
}
