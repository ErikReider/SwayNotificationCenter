namespace SwayNotificationCenter.Widgets.Mpris {
    public struct Config {
        int image_size;
        int image_radius;
    }

    public class Mpris : BaseWidget {
        public override string widget_name {
            get {
                return "mpris";
            }
        }

        const string MPRIS_PREFIX = "org.mpris.MediaPlayer2.";
        HashTable<string, MprisPlayer> players = new HashTable<string, MprisPlayer> (str_hash, str_equal);

        DBusInterface dbus_iface;

        Hdy.Carousel carousel;
        Hdy.CarouselIndicatorDots carousel_dots;

        // Default config values
        Config mpris_config = Config () {
            image_size = 96,
            image_radius = 12,
        };

        public Mpris (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);
            set_orientation (Gtk.Orientation.VERTICAL);
            set_valign (Gtk.Align.START);
            set_vexpand (false);

            carousel = new Hdy.Carousel ();
#if HAVE_LATEST_LIBHANDY
            carousel.allow_scroll_wheel = false;
#endif
            add (carousel);

            carousel_dots = new Hdy.CarouselIndicatorDots ();
            carousel_dots.set_carousel (carousel);
            carousel_dots.show ();
            add (carousel_dots);

            // Config
            Json.Object ? config = get_config (this);
            if (config != null) {
                // Get image-size
                get_prop<int> (config, "image-size", ref mpris_config.image_size);

                // Get image-border-radius
                get_prop<int> (config, "image-radius", ref mpris_config.image_radius);
                // Clamp the radius
                mpris_config.image_radius = mpris_config.image_radius.clamp (
                    0, (int) (mpris_config.image_size * 0.5));
            }

            hide ();
            try {
                setup_mpris ();
            } catch (Error e) {
                error ("MPRIS Widget error: %s", e.message);
            }
        }

        /**
         * Forces the carousel to reload its style_context.
         * Fixes carousel items not redrawing when window isn't visible.
         * Probably related to: https://gitlab.gnome.org/GNOME/libhandy/-/issues/363
         */
        public override void on_cc_visibility_change (bool value) {
            if (!value) return;
            carousel.get_style_context ().changed ();
            foreach (var child in carousel.get_children ()) {
                child.get_style_context ().changed ();
            }
        }

        private void setup_mpris () throws Error {
            dbus_iface = Bus.get_proxy_sync (BusType.SESSION,
                                             "org.freedesktop.DBus",
                                             "/org/freedesktop/DBus");
            string[] names = dbus_iface.list_names ();
            foreach (string name in names) {
                if (!name.has_prefix (MPRIS_PREFIX)) continue;
                if (check_player_exists (name)) return;
                MprisSource ? source = MprisSource.get_player (name);
                if (source != null) add_player (name, source);
            }

            dbus_iface.name_owner_changed.connect ((name, old_owner, new_owner) => {
                if (!name.has_prefix (MPRIS_PREFIX)) return;
                if (old_owner != "") {
                    remove_player (name);
                    return;
                }
                if (check_player_exists (name)) return;
                MprisSource ? source = MprisSource.get_player (name);
                if (source != null) add_player (name, source);
            });
        }

        private bool check_player_exists (string name) {
            foreach (string name_check in players.get_keys_as_array ()) {
                if (name_check.has_prefix (name)
                    || name.has_prefix (name_check)) return true;
            }
            return false;
        }

        private void add_player (string name, MprisSource source) {
            MprisPlayer player = new MprisPlayer (source, mpris_config);
            player.get_style_context ().add_class ("%s-player".printf (css_class_name));
            carousel.prepend (player);
            // this.pack_start (player, false, false, 0);
            players.set (name, player);

            if (!visible) show ();

            // Scroll to the new player
            carousel.scroll_to (player);
        }

        private void remove_player (string name) {
            string ? key;
            MprisPlayer ? player;
            bool result = players.lookup_extended (name, out key, out player);
            if (!result || key == null || player == null) return;
            player.before_destroy ();
            player.destroy ();
            players.remove (name);

            if (carousel.get_children ().length () == 0) hide ();
        }
    }
}
