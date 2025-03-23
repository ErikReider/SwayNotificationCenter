namespace SwayNotificationCenter.Widgets.Mpris {
    public class MprisSource : Object {
        public MprisMediaPlayer media_player { private set; get; }
        private DbusPropChange props;

        public signal void properties_changed (string iface,
                                               HashTable<string, Variant> changed,
                                               string[] invalid);

        public const string INTERFACE_PATH = "/org/mpris/MediaPlayer2";

        private MprisSource (MprisMediaPlayer _media_player, DbusPropChange _props) {
            this.media_player = _media_player;
            this.props = _props;
            this.props.properties_changed.connect (
                (i, c, inv) => properties_changed (i, c, inv));
        }

        public static MprisSource ? get_player (string bus_name) {
            MprisMediaPlayer ? player;
            DbusPropChange ? props;
            try {
                player = Bus.get_proxy_sync (BusType.SESSION, bus_name, INTERFACE_PATH);
            } catch (Error e) {
                message (e.message);
                return null;
            }
            try {
                props = Bus.get_proxy_sync (BusType.SESSION, bus_name, INTERFACE_PATH);
            } catch (Error e) {
                message (e.message);
                return null;
            }
            if (player == null || props == null) return null;
            return new MprisSource (player, props);
        }

        public Variant ? get_mpris_player_prop (string property_name) {
            try {
                return props.get ("org.mpris.MediaPlayer2.Player", property_name);
            } catch (Error e) {}
            return null;
        }

        public Variant ? get_mpris_prop (string property_name) {
            try {
                return props.get ("org.mpris.MediaPlayer2", property_name);
            } catch (Error e) {}
            return null;
        }
    }

    /** MPRIS uses properties_changed for player changes */
    [DBus (name = "org.freedesktop.DBus.Properties")]
    public interface DbusPropChange : Object {
        public signal void properties_changed (string iface,
                                               HashTable<string, Variant> changed,
                                               string[] invalid);

        public abstract Variant get (string iface_name, string property_name) throws Error;
    }

    [DBus (name = "org.mpris.MediaPlayer2")]
    public interface MprisProps : Object {
        public abstract string desktop_entry { owned get; }
        public abstract string identity { owned get; }
    }

    [DBus (name = "org.mpris.MediaPlayer2.Player")]
    public interface MprisMediaPlayer : MprisProps {
        public abstract async void next () throws Error;
        public abstract async void previous () throws Error;
        public abstract async void pause () throws Error;
        public abstract async void play_pause () throws Error;
        public abstract async void stop () throws Error;
        public abstract async void play () throws Error;

        public abstract string playback_status { owned get; }
        public abstract HashTable<string, Variant> metadata { owned get; }
        public abstract bool can_go_next { owned get; }
        public abstract bool can_go_previous { owned get; }
        public abstract bool can_play { owned get; }
        public abstract bool can_pause { owned get; }
        public abstract bool can_control { owned get; }
        public abstract bool can_seek { owned get; }

        public abstract bool shuffle { owned get; set; }
        public abstract string loop_status { owned get; set; }
    }

    [DBus (name = "org.freedesktop.DBus")]
    public interface DBusInterface : Object {
        public abstract string[] list_names () throws Error;
        public signal void name_owner_changed (string name,
                                               string old_owner,
                                               string new_owner);
    }
}
