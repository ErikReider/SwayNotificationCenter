namespace SwayNotificationCenter.Widgets.Mpris {
    public enum AlbumArtState {
        ALWAYS, WHEN_AVAILABLE, NEVER;

        public static AlbumArtState parse (string value) {
            switch (value) {
                default:
                case "always":
                    return AlbumArtState.ALWAYS;
                case "when-available":
                    return AlbumArtState.WHEN_AVAILABLE;
                case "never":
                    return AlbumArtState.NEVER;
            }
        }
    }

    public struct Config {
        [Version (deprecated = true, replacement = "CSS root variable")]
        int image_size;
        AlbumArtState show_album_art;
        bool autohide;
        string[] blacklist;
        bool loop_carousel;
        // New customization options
        bool show_title;
        bool show_subtitle;
        bool show_background;
        bool show_shuffle;
        bool show_repeat;
        bool show_favorite;
        int button_size;
        bool compact_mode;
    }

    public class Mpris : BaseWidget {
        public override string widget_name {
            get {
                return "mpris";
            }
        }

        const string MPRIS_PREFIX = "org.mpris.MediaPlayer2.";
        HashTable<string, MprisPlayer> players = new HashTable<string, MprisPlayer> (str_hash,
                                                                                     str_equal);

        DBusInterface dbus_iface;

        Gtk.Button button_prev;
        Gtk.Button button_next;
        Gtk.Box carousel_box;
        Adw.Carousel carousel;
        Adw.CarouselIndicatorDots carousel_dots;

        // Default config values
        Config mpris_config = Config () {
            image_size = -1,
            show_album_art = AlbumArtState.ALWAYS,
            autohide = false,
            loop_carousel = false,
            // defaults for new options
            show_title = true,
            show_subtitle = true,
            show_background = true,
            show_shuffle = true,
            show_repeat = true,
            show_favorite = true,
            button_size = -1,
            compact_mode = false,
        };

        public Mpris (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);
            set_orientation (Gtk.Orientation.VERTICAL);
            set_valign (Gtk.Align.START);
            set_vexpand (false);

            carousel_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                visible = true,
            };

            button_prev = new Gtk.Button.from_icon_name ("go-previous") {
                has_frame = false,
                visible = false,
            };
            button_prev.clicked.connect (() => change_carousel_position (-1));

            button_next = new Gtk.Button.from_icon_name ("go-next") {
                has_frame = false,
                visible = false,
            };
            button_next.clicked.connect (() => change_carousel_position (1));

            carousel = new Adw.Carousel () {
                visible = true,
            };
            carousel.allow_scroll_wheel = true;
            carousel.page_changed.connect ((index) => {
                if (carousel.n_pages <= 1) {
                    button_prev.sensitive = false;
                    button_next.sensitive = false;
                    return;
                }
                button_prev.sensitive = (index > 0) || mpris_config.loop_carousel;
                button_next.sensitive = (index < carousel.n_pages - 1) ||
                    mpris_config.loop_carousel;
            });

            carousel_box.append (button_prev);
            carousel_box.append (carousel);
            carousel_box.append (button_next);
            append (carousel_box);

            carousel_dots = new Adw.CarouselIndicatorDots ();
            carousel_dots.set_carousel (carousel);
            carousel_dots.set_halign (Gtk.Align.CENTER);
            carousel_dots.set_valign (Gtk.Align.CENTER);
            carousel_dots.set_visible (false);
            append (carousel_dots);

            // Config
            Json.Object ?config = get_config (this);
            if (config != null) {
                // Get image-size
                bool image_size_found;
                int ?image_size = get_prop<int> (config, "image-size", out image_size_found);
                if (image_size_found && image_size != null) {
                    mpris_config.image_size = image_size;
                }

                bool show_art_found;
                string ?show_album_art = get_prop<string> (config, "show-album-art",
                                                           out show_art_found);
                if (show_art_found && show_album_art != null) {
                    mpris_config.show_album_art = AlbumArtState.parse (show_album_art);
                }

                Json.Array ?blacklist = get_prop_array (config, "blacklist");
                if (blacklist != null) {
                    mpris_config.blacklist = new string[blacklist.get_length ()];
                    for (int i = 0; i < blacklist.get_length (); i++) {
                        if (blacklist.get_element (i).get_node_type () != Json.NodeType.VALUE) {
                            warning ("Blacklist entries should be strings");
                            continue;
                        }
                        mpris_config.blacklist[i] = blacklist.get_string_element (i);
                    }
                }

                // Get autohide
                bool autohide_found;
                bool ?autohide = get_prop<bool> (config, "autohide", out autohide_found);
                if (autohide_found) {
                    mpris_config.autohide = autohide;
                }

                // Get loop
                bool loop_carousel_found;
                bool ?loop_carousel = get_prop<bool> (config, "loop-carousel",
                                                      out loop_carousel_found);
                if (loop_carousel_found) {
                    mpris_config.loop_carousel = loop_carousel;
                }

                // New options
                bool show_title_found;
                bool ?show_title = get_prop<bool> (config, "show-title", out show_title_found);
                if (show_title_found && show_title != null) {
                    mpris_config.show_title = show_title;
                }

                bool show_subtitle_found;
                bool ?show_subtitle = get_prop<bool> (
                    config, "show-subtitle", out show_subtitle_found
                );
                if (show_subtitle_found && show_subtitle != null) {
                    mpris_config.show_subtitle = show_subtitle;
                }

                bool show_background_found;
                bool ?show_background = get_prop<bool> (
                    config, "show-background", out show_background_found
                );
                if (show_background_found && show_background != null) {
                    mpris_config.show_background = show_background;
                }

                bool show_shuffle_found;
                bool ?show_shuffle = get_prop<bool> (
                    config, "show-shuffle", out show_shuffle_found
                );
                if (show_shuffle_found && show_shuffle != null) {
                    mpris_config.show_shuffle = show_shuffle;
                }

                bool show_repeat_found;
                bool ?show_repeat = get_prop<bool> (config, "show-repeat", out show_repeat_found);
                if (show_repeat_found && show_repeat != null) {
                    mpris_config.show_repeat = show_repeat;
                }

                bool show_favorite_found;
                bool ?show_favorite = get_prop<bool> (
                    config, "show-favorite", out show_favorite_found
                );
                if (show_favorite_found && show_favorite != null) {
                    mpris_config.show_favorite = show_favorite;
                }

                bool button_size_found;
                int ?button_size = get_prop<int> (config, "button-size", out button_size_found);
                if (button_size_found && button_size != null) {
                    mpris_config.button_size = button_size;
                }

                bool compact_mode_found;
                bool ?compact_mode = get_prop<bool> (
                    config, "compact-mode", out compact_mode_found
                );
                if (compact_mode_found && compact_mode != null) {
                    mpris_config.compact_mode = compact_mode;
                }
            }

            hide ();
            try {
                setup_mpris ();
            } catch (Error e) {
                critical ("MPRIS Widget error: %s", e.message);
            }
        }

        private void setup_mpris () throws Error {
            dbus_iface = Bus.get_proxy_sync (BusType.SESSION,
                                             "org.freedesktop.DBus",
                                             "/org/freedesktop/DBus");
            string[] names = dbus_iface.list_names ();
            foreach (string name in names) {
                if (!name.has_prefix (MPRIS_PREFIX)) {
                    continue;
                }
                if (is_blacklisted (name)) {
                    continue;
                }
                if (check_player_exists (name)) {
                    return;
                }
                MprisSource ?source = MprisSource.get_player (name);
                if (source != null) {
                    add_player (name, source);
                }
            }

            dbus_iface.name_owner_changed.connect ((name, old_owner, new_owner) => {
                if (!name.has_prefix (MPRIS_PREFIX)) {
                    return;
                }
                if (old_owner != "") {
                    remove_player (name);
                    return;
                }
                if (is_blacklisted (name)) {
                    return;
                }
                if (check_player_exists (name)) {
                    return;
                }
                MprisSource ?source = MprisSource.get_player (name);
                if (source != null) {
                    add_player (name, source);
                }
            });
        }

        private bool check_player_exists (string name) {
            foreach (string name_check in players.get_keys_as_array ()) {
                if (name_check.has_prefix (name)
                    || name.has_prefix (name_check)) {
                    return true;
                }
            }
            return false;
        }

        private bool check_player_metadata_empty (string name) {
            MprisPlayer ?player = players.lookup (name);
            if (player == null) {
                return true;
            }
            HashTable<string, Variant> metadata = player.source.media_player.metadata;
            if (metadata == null || metadata.size () == 0) {
                debug ("Metadata is empty");
                return true;
            }
            return false;
        }

        private bool check_carousel_has_player (MprisPlayer player) {
            return player != null && player.parent == carousel;
        }

        private void add_player_to_carousel (string name) {
            MprisPlayer ?player = players.lookup (name);
            if (player == null || check_carousel_has_player (player)) {
                return;
            }
            // HACK: The carousel doesn't focus the prepended player when not mapped.
            carousel.append (player);
            carousel.reorder (player, 0);

            if (carousel.n_pages > 1) {
                button_prev.show ();
                button_next.show ();
                carousel_dots.set_visible (true);
                // Scroll to the new player
                carousel.scroll_to (player, false);
            }

            if (!visible) {
                show ();
            }
        }

        private void add_player (string name, MprisSource source) {
            MprisPlayer player = new MprisPlayer (source, mpris_config);
            player.add_css_class ("%s-player".printf (css_class_name));
            players.set (name, player);

            if (mpris_config.autohide) {
                player.content_updated.connect (() => {
                    if (!check_player_metadata_empty (name)) {
                        add_player_to_carousel (name);
                    } else {
                        remove_player_from_carousel (name);
                    }
                });
                if (check_player_metadata_empty (name)) {
                    return;
                }
            }

            add_player_to_carousel (name);
        }

        private void remove_player_from_carousel (string name) {
            MprisPlayer ?player = players.lookup (name);
            if (player == null || !check_carousel_has_player (player)) {
                return;
            }
            carousel.remove (player);

            uint children_length = carousel.n_pages;
            if (children_length == 0) {
                hide ();
            }
            if (children_length <= 1) {
                button_prev.hide ();
                button_next.hide ();
                carousel_dots.set_visible (false);
            }
        }

        private void remove_player (string name) {
            string ?key;
            MprisPlayer ?player;
            bool result = players.lookup_extended (name, out key, out player);
            if (!result || key == null || player == null) {
                return;
            }

            remove_player_from_carousel (name);

            player.before_destroy ();
            players.remove (name);
        }

        private void change_carousel_position (int delta) {
            uint children_length = carousel.n_pages;
            if (children_length == 0) {
                return;
            }
            uint position;
            if (mpris_config.loop_carousel) {
                position = ((uint) carousel.position + delta) % children_length;
            } else {
                position = ((uint) carousel.position + delta)
                     .clamp (0, (children_length - 1));
            }
            carousel.scroll_to (carousel.get_nth_page (position), true);
        }

        private bool is_blacklisted (string name) {
            foreach (string blacklistedPattern in mpris_config.blacklist) {
                if (blacklistedPattern == null || blacklistedPattern.length == 0) {
                    continue;
                }
                if (GLib.Regex.match_simple (blacklistedPattern, name, RegexCompileFlags.DEFAULT,
                                             0)) {
                    message ("\"%s\" is blacklisted", name);
                    return true;
                }
            }
            return false;
        }
    }
}
