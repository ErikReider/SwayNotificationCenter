using PulseAudio;
using Gee;

namespace SwayNotificationCenter.Widgets {
    public class PulseCardProfile : Object {
        public string name;
        public string description;
        public uint32 n_sinks;
        public uint32 priority;
        int available;

        public PulseCardProfile (CardProfileInfo2 * profile) {
            this.name = profile->name;
            this.description = profile->description;
            this.n_sinks = profile->n_sinks;
            this.priority = profile->priority;
            this.available = profile->available;
        }

        public bool cmp (PulseCardProfile profile) {
            return profile.name == name
                   && profile.description == description
                   && profile.n_sinks == n_sinks
                   && profile.priority == priority
                   && profile.available == available;
        }
    }

    public class PulseDevice : Object {

        public bool removed { get; set; default = false; }

        public bool has_card { get; set; default = true; }

        /** The card index: ex. `Card #49` */
        public uint32 card_index { get; set; }
        /** Sink index: ex. `Sink #55` */
        public uint32 device_index { get; set; }

        /** Input or Output */
        public Direction direction { get; set; }

        /** Is default Sink */
        public bool is_default { get; set; }
        /** If the device is virtual */
        public bool is_virtual { get; set; default = false; }
        /** If the device is a bluetooth device */
        public bool is_bluetooth { get; set; default = false; }

        /** The icon name: `device.icon_name` */
        public string icon_name { get; set; }

        /** The card name: `Name` */
        public string card_name { get; set; }
        /** The card description: `device.description` */
        public string card_description { get; set; }
        /** The card active profile: `Active Profile` */
        public string card_active_profile { get; set; }
        /** The card sink port name: `Active Port` */
        public string card_sink_port_name { get; set; }

        /** The Sink name: `Name` */
        public string ? device_name { get; set; }
        /** The Sink description: `Description` */
        public string device_description { get; set; }
        /** If the Sink is muted: `Mute` */
        public bool is_muted { get; set; }

        public double volume { get; set; }
        public float balance { get; set; default = 0; }
        public CVolume cvolume;
        public ChannelMap channel_map;
        public LinkedList<Operation> volume_operations { get; set; }

        /** Gets the name to be shown to the user:
         * "port_description - card_description"
         */
        public string ? get_display_name () {
            if (card_name == null) {
                return device_description;
            }
            string p_desc = port_description;
            string c_desc = card_description;
            return "%s - %s".printf (p_desc, c_desc);
        }

        /** Compares PulseDevices. Returns true if they're the same */
        public bool cmp (PulseDevice device) {
            return device.card_index == card_index
                   && device.device_index == device_index
                   && device.device_name == device_name
                   && device.device_description == device_description
                   && device.is_default == is_default
                   && device.removed == removed
                   && device.card_active_profile == card_active_profile
                   && device.port_name == port_name;
        }

        /**
         * Gets the name to be shown to the user:
         * If has card: "card_description:port_name"
         * If cardless: "device_index:device_description"
         */
        public string get_current_hash_key () {
            if (card_name == null) {
                return get_hash_map_key (device_index.to_string (),
                                         device_description);
            }
            return get_hash_map_key (card_description, port_name);
        }

        /** Gets the name to be shown to the user:
         * "card_description:port_name"
         */
        public static string get_hash_map_key (string c_desc, string p_name) {
            return string.joinv (":", new string[] { c_desc, p_name });
        }

        /** The port name: `Name` */
        public string port_name { get; set; }
        /** The port name: `Description` */
        public string port_description { get; set; }
        /** The port name: `card.profile.port` */
        public string port_id { get; set; }
        /** All port profiles */
        public string[] port_profiles { get; set; }
        public Array<PulseCardProfile> profiles { get; set; }
        public PulseCardProfile ? active_profile { get; set; }

        construct {
            volume_operations = new LinkedList<Operation> ();
        }
    }
}
