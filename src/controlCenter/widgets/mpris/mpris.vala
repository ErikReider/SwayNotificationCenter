namespace SwayNotificationCenter.Widgets.Mpris {
    public struct Config {
        int image_size;
        int image_radius;
        bool blur;
        string[] blacklist;
    }

    public class Mpris : BaseWidget {
        public override string widget_name {
            get {
                return "mpris";
            }
        }

        private const int FADE_WIDTH = 20;

        const string MPRIS_PREFIX = "org.mpris.MediaPlayer2.";
        HashTable<string, MprisPlayer> players = new HashTable<string, MprisPlayer> (str_hash, str_equal);

        DBusInterface dbus_iface;

        Gtk.Button button_prev;
        Gtk.Button button_next;
        Gtk.Box carousel_box;
        Hdy.Carousel carousel;
        Hdy.CarouselIndicatorDots carousel_dots;

        // Default config values
        Config mpris_config = Config () {
            image_size = 96,
            image_radius = 12,
            blur = true,
        };

        public Mpris (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);
            set_orientation (Gtk.Orientation.VERTICAL);
            set_valign (Gtk.Align.START);
            set_vexpand (false);

            carousel_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                visible = true,
            };

            button_prev = new Gtk.Button.from_icon_name ("go-previous", Gtk.IconSize.BUTTON) {
                relief = Gtk.ReliefStyle.NONE,
                visible = false,
            };
            button_prev.clicked.connect (() => change_carousel_position (-1));

            button_next = new Gtk.Button.from_icon_name ("go-next", Gtk.IconSize.BUTTON) {
                relief = Gtk.ReliefStyle.NONE,
                visible = false,
            };
            button_next.clicked.connect (() => change_carousel_position (1));

            carousel = new Hdy.Carousel () {
                visible = true,
            };
            carousel.allow_scroll_wheel = true;
            carousel.draw.connect (carousel_draw_cb);
            carousel.page_changed.connect ((index) => {
                GLib.List<weak Gtk.Widget> children = carousel.get_children ();
                int children_length = (int) children.length ();
                if (children_length <= 1) {
                    button_prev.sensitive = false;
                    button_next.sensitive = false;
                    return;
                }
                button_prev.sensitive = index > 0;
                button_next.sensitive = index < children_length - 1;
            });

            carousel_box.add (button_prev);
            carousel_box.add (carousel);
            carousel_box.add (button_next);
            add (carousel_box);

            carousel_dots = new Hdy.CarouselIndicatorDots ();
            carousel_dots.set_carousel (carousel);
            carousel_dots.show ();
            add (carousel_dots);

            // Config
            Json.Object ? config = get_config (this);
            if (config != null) {
                // Get image-size
                int? image_size = get_prop<int> (config, "image-size");
                if (image_size != null) mpris_config.image_size = image_size;

                // Get image-border-radius
                int? image_radius = get_prop<int> (config, "image-radius");
                if (image_radius != null) mpris_config.image_radius = image_radius;
                // Clamp the radius
                mpris_config.image_radius = mpris_config.image_radius.clamp (
                    0, (int) (mpris_config.image_size * 0.5));

                // Get blur
                bool blur_found;
                bool? blur = get_prop<bool> (config, "blur", out blur_found);
                if (blur_found) mpris_config.blur = blur;

                Json.Array ? blacklist = get_prop_array (config, "blacklist");
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
            }

            hide ();
            try {
                setup_mpris ();
            } catch (Error e) {
                error ("MPRIS Widget error: %s", e.message);
            }
        }

        private bool carousel_draw_cb (Cairo.Context cr) {
            Gtk.Allocation alloc;
            carousel.get_allocated_size (out alloc, null);

            Cairo.Pattern left_fade_gradient = new Cairo.Pattern.linear (0, 0, 1, 0);
            left_fade_gradient.add_color_stop_rgba (0, 1, 1, 1, 1);
            left_fade_gradient.add_color_stop_rgba (1, 1, 1, 1, 0);
            Cairo.Pattern right_fade_gradient = new Cairo.Pattern.linear (0, 0, 1, 0);
            right_fade_gradient.add_color_stop_rgba (0, 1, 1, 1, 0);
            right_fade_gradient.add_color_stop_rgba (1, 1, 1, 1, 1);

            cr.save ();
            cr.push_group ();

            // Draw widgets
            carousel.draw.disconnect (carousel_draw_cb);
            carousel.draw (cr);
            carousel.draw.connect (carousel_draw_cb);

            /// Draw vertical fade

            // Top fade
            cr.save ();
            cr.scale (FADE_WIDTH, alloc.height);
            cr.rectangle (0, 0, FADE_WIDTH, alloc.height);
            cr.set_source (left_fade_gradient);
            cr.set_operator (Cairo.Operator.DEST_OUT);
            cr.fill ();
            cr.restore ();
            // Bottom fade
            cr.save ();
            cr.translate (alloc.width - FADE_WIDTH, 0);
            cr.scale (FADE_WIDTH, alloc.height);
            cr.rectangle (0, 0, FADE_WIDTH, alloc.height);
            cr.set_source (right_fade_gradient);
            cr.set_operator (Cairo.Operator.DEST_OUT);
            cr.fill ();
            cr.restore ();

            cr.pop_group_to_source ();
            cr.paint ();
            cr.restore ();
            return true;
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
                if (is_blacklisted (name)) continue;
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
                if (is_blacklisted (name)) return;
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
            players.set (name, player);

            if (!visible) show ();

            // Scroll to the new player
            carousel.scroll_to (player);
            uint children_length = carousel.get_children ().length ();
            if (children_length > 1) {
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

            uint children_length = carousel.get_children ().length ();
            if (children_length == 0) {
                hide ();
            }
            if (children_length <= 1) {
                button_prev.hide ();
                button_next.hide ();
            }
        }

        private void change_carousel_position (int delta) {
            GLib.List<weak Gtk.Widget> children = carousel.get_children ();
            int children_length = (int) children.length ();
            if (children_length == 0) return;
            int position = ((int) carousel.position + delta).clamp (
                0, children_length - 1);
            carousel.scroll_to (children.nth_data (position));
        }

        private bool is_blacklisted (string name) {
            foreach (string blacklistedPattern in mpris_config.blacklist) {
                if (blacklistedPattern == null || blacklistedPattern.length == 0) {
                    continue;
                }
                if (GLib.Regex.match_simple (blacklistedPattern, name, GLib.RegexCompileFlags.JAVASCRIPT_COMPAT, 0)) {
                    message ("\"%s\" is blacklisted", name);
                    return true;
                }
            }
            return false;
        }
    }
}
