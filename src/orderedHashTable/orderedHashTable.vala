namespace SwayNotificationCenter {
    /** A regular GLib HashTable but preserves the order of inserted keys and values */
    public class OrderedHashTable<T> {
        private HashTable<string, T> hash_table;
        private List<string> order;

        public uint length {
            get {
                return hash_table.length;
            }
        }

        public OrderedHashTable () {
            hash_table = new HashTable<string, T> (str_hash, str_equal);
            order = new List<string> ();
        }

        public unowned T @get (string key) {
            return hash_table.get (key);
        }

        public void insert (owned string key, owned T value) {
            if (!hash_table.contains (key)) {
                order.append (key);
            }
            hash_table.insert (key, value);
        }

        public List<weak string> get_keys () {
            return order.copy ();
        }

        public bool lookup_extended (string lookup_key, out unowned string orig_key,
                                     out unowned T value) {
            return hash_table.lookup_extended (lookup_key, out orig_key, out value);
        }
    }
}
