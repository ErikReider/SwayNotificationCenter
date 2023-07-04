namespace SwayNotificationCenter.Widgets.Mpris {
    public class Mpris : BaseWidget {
        public override string widget_name {
            get {
                return "mpris";
            }
        }

        const string MPRIS_PREFIX = "org.mpris.MediaPlayer2.";
        HashTable<string, MprisPlayer> players = new HashTable<string, MprisPlayer> (str_hash, str_equal);

        DBusInterface dbus_iface;

        Gtk.Button button_prev;
        Gtk.Button button_next;
        Gtk.Box carousel_box;
        Adw.Carousel carousel;
        Adw.CarouselIndicatorDots carousel_dots;

        bool starting = true;

        // Default config values
        int image_size = 96;

        public Mpris (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);
            set_orientation (Gtk.Orientation.VERTICAL);
            set_valign (Gtk.Align.START);
            set_vexpand (false);

            carousel_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

            button_prev = new Gtk.Button.from_icon_name ("go-previous") {
                visible = false,
            };
            button_prev.clicked.connect (() => change_carousel_position (-1));

            button_next = new Gtk.Button.from_icon_name ("go-next") {
                visible = false,
            };
            button_next.clicked.connect (() => change_carousel_position (1));

            carousel = new Adw.Carousel () {
                allow_scroll_wheel = true,
                hexpand = true,
            };
            carousel.page_changed.connect ((index) => {
                if (carousel.n_pages <= 1) {
                    button_prev.sensitive = false;
                    button_next.sensitive = false;
                    return;
                }
                button_prev.sensitive = index > 0;
                button_next.sensitive = index < carousel.n_pages - 1;
            });

            carousel_box.append (button_prev);
            carousel_box.append (carousel);
            carousel_box.append (button_next);
            append (carousel_box);

            carousel_dots = new Adw.CarouselIndicatorDots ();
            carousel_dots.set_carousel (carousel);
            carousel_dots.show ();
            append (carousel_dots);

            // Config
            Json.Object ? config = get_config (this);
            if (config != null) {
                // Get image-size
                int? image_size = get_prop<int> (config, "image-size");
                if (image_size != null) this.image_size = image_size;
            }

            hide ();
            try {
                setup_mpris ();
            } catch (Error e) {
                error ("MPRIS Widget error: %s", e.message);
            }
            starting = false;
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
            MprisPlayer player = new MprisPlayer (source, image_size, css_class_name);
            carousel.prepend (player);
            players.set (name, player);

            if (!visible) show ();

            // Scroll to the new player
            // TODO: Open issue about scroll_to not being run before the window is shown
            // Also affects notifications
            carousel.scroll_to (player, !starting);
            if (carousel.n_pages > 1) {
                button_prev.show ();
                button_next.show ();
            }
        }

        private void remove_player (string name) {
            string ? key;
            MprisPlayer ? player;
            bool result = players.lookup_extended (name, out key, out player);
            if (!result || key == null || player == null) return;
            player.before_destroy ();
            player.destroy ();
            players.remove (name);
            carousel.remove (player);

            if (carousel.n_pages == 0) {
                hide ();
            } else if (carousel.n_pages <= 1) {
                button_prev.hide ();
                button_next.hide ();
            }
        }

        private void change_carousel_position (int delta) {
            if (carousel.n_pages == 0) return;
            int position = ((int) carousel.position + delta).clamp (
                0, (int) carousel.n_pages - 1);
            carousel.scroll_to (carousel.get_nth_page (position), true);
        }
    }
}
