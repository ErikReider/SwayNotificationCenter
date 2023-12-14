namespace SwayNotificationCenter.Widgets.Mpris {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/controlCenter/widgets/mpris/mpris_player.ui")]
    public class MprisPlayer : Gtk.Box {
        [GtkChild]
        unowned Gtk.Label title;
        [GtkChild]
        unowned Gtk.Label sub_title;

        [GtkChild]
        unowned Gtk.Image album_art;

        [GtkChild]
        unowned Gtk.Button button_shuffle;
        [GtkChild]
        unowned Gtk.Button button_prev;
        [GtkChild]
        unowned Gtk.Button button_play_pause;
        [GtkChild]
        unowned Gtk.Image button_play_pause_img;
        [GtkChild]
        unowned Gtk.Button button_next;
        [GtkChild]
        unowned Gtk.Button button_repeat;
        [GtkChild]
        unowned Gtk.Image button_repeat_img;

        public MprisSource source { construct; get; }

        private const double UNSELECTED_OPACITY = 0.5;

        public const string ICON_REPEAT = "media-playlist-repeat-symbolic";
        public const string ICON_REPEAT_SONG = "media-playlist-repeat-song-symbolic";

        public const string ICON_PLAY = "media-playback-start-symbolic";
        public const string ICON_PAUSE = "media-playback-pause-symbolic";

        private Cancellable album_art_cancellable = new Cancellable ();
        private string prev_art_url;
        private DesktopAppInfo ? desktop_entry = null;

        private unowned Config mpris_config;

        public MprisPlayer (MprisSource source, Config mpris_config) {
            Object (source: source);
            this.mpris_config = mpris_config;

            source.properties_changed.connect (properties_changed);

            // Init content
            update_content ();

            /* Callbacks */

            // Shuffle
            button_shuffle.clicked.connect (() => {
                source.media_player.shuffle = !source.media_player.shuffle;
                // Wait until dbus value has updated
                button_shuffle.sensitive = false;
            });
            // Repeat
            button_repeat.clicked.connect (() => {
                switch (source.media_player.loop_status) {
                    case "None":
                        source.media_player.loop_status = "Playlist";
                        break;
                    case "Playlist":
                        source.media_player.loop_status = "Track";
                        break;
                    case "Track":
                        source.media_player.loop_status = "None";
                        break;
                    default:
                        return;
                }
                // Wait until dbus value has updated
                button_repeat.sensitive = false;
            });
            // Prev
            button_prev.clicked.connect (() => {
                source.media_player.previous.begin (() => {
                    update_buttons (source.media_player.metadata);
                });
            });
            // Next
            button_next.clicked.connect (() => {
                source.media_player.next.begin (() => {
                    update_buttons (source.media_player.metadata);
                });
            });
            // Play/Pause
            button_play_pause.clicked.connect (() => {
                source.media_player.play_pause.begin (() => {
                    update_buttons (source.media_player.metadata);
                });
            });
        }

        public void before_destroy () {
            source.properties_changed.disconnect (properties_changed);
        }

        private void properties_changed (string iface,
                                         HashTable<string, Variant> changed,
                                         string[] invalid) {
            var metadata = source.media_player.metadata;
            foreach (string key in changed.get_keys ()) {
                switch (key) {
                    case "DesktopEntry":
                        update_desktop_entry ();
                        break;
                    case "PlaybackStatus":
                    case "CanPause":
                    case "CanPlay":
                        update_button_play_pause (metadata);
                        break;
                    case "Metadata":
                        update_content ();
                        break;
                    case "Shuffle":
                        update_button_shuffle (metadata);
                        break;
                    case "LoopStatus":
                        update_button_repeat (metadata);
                        break;
                    case "CanGoPrevious":
                        update_button_prev (metadata);
                        break;
                    case "CanGoNext":
                        update_button_forward (metadata);
                        break;
                    case "CanControl":
                        update_buttons (metadata);
                        break;
                }
            }
            debug ("Changed: %s", string.joinv (", ", changed.get_keys_as_array ()));
        }

        private void update_content () {
            HashTable<string, Variant> metadata = source.media_player.metadata;

            // Desktop Entry
            update_desktop_entry ();

            // Album art
            update_album_art.begin (metadata);

            // Title
            update_title (metadata);

            // Subtitle
            update_sub_title (metadata);

            // Update the buttons
            update_buttons (metadata);
        }

        private void update_buttons (HashTable<string, Variant> metadata) {
            // Shuffle check
            update_button_shuffle (metadata);

            // Prev check
            update_button_prev (metadata);

            // Play/Pause
            update_button_play_pause (metadata);

            // Next check
            update_button_forward (metadata);

            // Repeat check
            update_button_repeat (metadata);
        }

        private void update_desktop_entry () {
            Variant ? entry_name = source.get_mpris_prop ("DesktopEntry");
            if (entry_name == null
                || !entry_name.is_of_type (VariantType.STRING)
                || entry_name.get_string () == "") {
                desktop_entry = null;
                return;
            }
            string name = "%s.desktop".printf (entry_name.get_string ());
            desktop_entry = new DesktopAppInfo (name);
        }

        private void update_title (HashTable<string, Variant> metadata) {
            if ("xesam:title" in metadata
                && metadata["xesam:title"].get_string () != "") {
                string str = metadata["xesam:title"].get_string ();
                title.set_text (str);
            } else {
                string ? name = null;
                if (desktop_entry is DesktopAppInfo) {
                    name = desktop_entry.get_display_name ();
                    if (name == "") name = desktop_entry.get_name ();
                }
                if (name == null) name = "Media Player";
                title.set_text (name);
            }
        }

        private void update_sub_title (HashTable<string, Variant> metadata) {
            // Get album
            string ? album = null;
            if ("xesam:album" in metadata
                && metadata["xesam:album"].get_string () != "") {
                album = metadata["xesam:album"].get_string ();
            }

            // Get first artist
            string ? artist = null;
            // Try to get either "artist" or "albumArtist"
            const string[] TYPES = { "xesam:artist", "xesam:albumArtist" };
            foreach (unowned string type in TYPES) {
                if (artist != null && artist.length > 0) break;
                if (type in metadata
                    && metadata[type].get_type_string () == "as") {
                    VariantIter iter = new VariantIter (metadata[type]);
                    Variant ? value = null;
                    while ((value = iter.next_value ()) != null) {
                        artist = value.get_string ();
                        break;
                    }
                }
            }

            string result = "";
            if (album != null) {
                if (artist != null && artist.length > 0) {
                    result = string.joinv (" - ", { artist, album });
                } else {
                    result = album;
                }
            }
            sub_title.set_text (result);
            // Hide if no album or artist
            sub_title.set_visible (result.length > 0);
        }

        private async void update_album_art (HashTable<string, Variant> metadata) {
            if ("mpris:artUrl" in metadata) {
                string url = metadata["mpris:artUrl"].get_string ();
                if (url == prev_art_url) return;
                prev_art_url = url;

                int scale = get_style_context ().get_scale ();

                Gdk.Pixbuf ? pixbuf = null;
                // Cancel previous download, reset the state and download again
                album_art_cancellable.cancel ();
                album_art_cancellable.reset ();
                try {
                    File file = File.new_for_uri (url);
                    InputStream stream = yield file.read_async (Priority.DEFAULT,
                                                                album_art_cancellable);

                    pixbuf = yield new Gdk.Pixbuf.from_stream_async (
                        stream, album_art_cancellable);
                } catch (Error e) {
                    debug ("Could not download album art for %s. Using fallback...",
                           source.media_player.identity);
                }
                if (pixbuf != null) {
                    var surface = Functions.scale_round_pixbuf (pixbuf,
                                                           mpris_config.image_size,
                                                           mpris_config.image_size,
                                                           scale,
                                                           mpris_config.image_radius);
                    pixbuf = Gdk.pixbuf_get_from_surface (surface,
                                                          0, 0,
                                                          mpris_config.image_size,
                                                          mpris_config.image_size);
                    album_art.set_from_pixbuf (pixbuf);
                    album_art.get_style_context ().set_scale (1);
                    return;
                }
            }
            // Get the app icon
            Icon ? icon = null;
            if (desktop_entry is DesktopAppInfo) {
                icon = desktop_entry.get_icon ();
            }
            if (icon != null) {
                album_art.set_from_gicon (icon, mpris_config.image_size);
            } else {
                // Default icon
                album_art.set_from_icon_name ("audio-x-generic-symbolic",
                                              mpris_config.image_size);
            }
        }

        private void update_button_shuffle (HashTable<string, Variant> metadata) {
            if (!(button_shuffle is Gtk.Widget)) return;

            if (source.media_player.can_control) {
                // Shuffle check
                Variant ? shuffle = source.get_mpris_player_prop ("Shuffle");
                if (shuffle == null || !shuffle.is_of_type (VariantType.BOOLEAN)) {
                    button_shuffle.sensitive = false;
                    button_shuffle.get_child ().opacity = 1;
                    button_shuffle.hide ();
                } else {
                    button_shuffle.sensitive = true;
                    button_shuffle.get_child ().opacity = source.media_player.shuffle ? 1 : UNSELECTED_OPACITY;
                    button_shuffle.show ();
                }
            } else {
                button_shuffle.hide ();
            }
        }

        private void update_button_prev (HashTable<string, Variant> metadata) {
            if (!(button_prev is Gtk.Widget)) return;

            button_prev.set_sensitive (source.media_player.can_go_previous
                                       && source.media_player.can_control);
        }

        private void update_button_play_pause (HashTable<string, Variant> metadata) {
            if (!(button_play_pause is Gtk.Widget)) return;

            string icon_name;
            bool check;
            switch (source.media_player.playback_status) {
                case "Playing":
                    icon_name = ICON_PAUSE;
                    check = source.media_player.can_pause;
                    break;
                case "Paused":
                case "Stopped":
                default:
                    icon_name = ICON_PLAY;
                    check = source.media_player.can_play;
                    break;
            }
            button_play_pause_img.icon_name = icon_name;
            button_play_pause.sensitive = check && source.media_player.can_control;
        }

        private void update_button_forward (HashTable<string, Variant> metadata) {
            if (!(button_next is Gtk.Widget)) return;

            button_next.set_sensitive (source.media_player.can_go_next
                                       && source.media_player.can_control);
        }

        private void update_button_repeat (HashTable<string, Variant> metadata) {
            if (!(button_repeat is Gtk.Widget)) return;

            if (source.media_player.can_control) {
                // Repeat check
                Variant ? repeat = source.get_mpris_player_prop ("LoopStatus");
                if (repeat == null || !repeat.is_of_type (VariantType.STRING)) {
                    button_repeat.sensitive = false;
                    button_repeat.hide ();
                } else {
                    string icon_name;
                    double opacity = 1.0;
                    bool remove_flat_css_class = true;
                    switch (repeat.get_string ()) {
                        default:
                        case "None":
                            icon_name = ICON_REPEAT;
                            opacity = UNSELECTED_OPACITY;
                            remove_flat_css_class = false;
                            break;
                        case "Playlist":
                            icon_name = ICON_REPEAT;
                            break;
                        case "Track":
                            icon_name = ICON_REPEAT_SONG;
                            break;
                    }
                    unowned Gtk.StyleContext ctx = button_repeat.get_style_context ();
                    if (remove_flat_css_class) ctx.remove_class ("flat");
                    else ctx.add_class ("flat");
                    button_repeat.get_child ().opacity = opacity;
                    button_repeat.sensitive = true;
                    button_repeat_img.icon_name = icon_name;
                    button_repeat.show ();
                }
            } else {
                button_repeat.hide ();
            }
        }
    }
}
