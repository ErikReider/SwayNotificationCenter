namespace SwayNotificationCenter {
    public class Cacher {
        private static Cacher _instance;

        /** Get the static singleton */
        public static unowned Cacher instance {
            get {
                if (_instance == null) _instance = new Cacher ();
                return _instance;
            }
        }

        private const string CACHE_FILE_STATE = "swaync-state.cache";
        private const FileCreateFlags FILE_FLAGS = FileCreateFlags.PRIVATE
                                                   | FileCreateFlags.REPLACE_DESTINATION;

        private string get_cache_path () {
            string path = Path.build_filename (Environment.get_user_cache_dir (),
                                               CACHE_FILE_STATE);

            File file = File.new_for_path (path);
            if (!file.query_exists ()) {
                try {
                    file.create (FILE_FLAGS);
                } catch (Error e) {
                    stderr.printf ("Error: %s\n", e.message);
                }
            }
            return path;
        }

        public bool cache_state (StateCache state) {
            string path = get_cache_path ();
            Json.Node json = Json.gobject_serialize (state);
            string data = Json.to_string (json, true);

            try {
                File file = File.new_for_path (path);

                return file.replace_contents (
                    data.data,
                    null,
                    false,
                    FILE_FLAGS,
                    null);
            } catch (Error e) {
                stderr.printf ("Cache state write error: %s\n", e.message);
                return false;
            }
        }

        public StateCache get_state_cache () {
            string path = get_cache_path ();
            StateCache s = null;
            try {
                Json.Parser parser = new Json.Parser ();
                parser.load_from_file (path);
                Json.Node ? node = parser.get_root ();
                if (node == null) {
                    throw new Json.ParserError.PARSE ("Node is null!");
                }

                StateCache model = Json.gobject_deserialize (
                    typeof (StateCache), node) as StateCache;
                if (model == null) {
                    throw new Json.ParserError.UNKNOWN ("Json model is null!");
                }
                s = model;
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }
            return s ?? new StateCache ();
        }
    }

    public class StateCache : Object {
        public bool dnd_state { get; set; default = false; }
    }
}
