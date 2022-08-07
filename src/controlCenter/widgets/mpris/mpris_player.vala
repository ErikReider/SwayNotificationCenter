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
        unowned Gtk.ToggleButton button_shuffle;
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

        public const string ICON_REPEAT = "media-playlist-repeat-symbolic";
        public const string ICON_REPEAT_SONG = "media-playlist-repeat-song-symbolic";

        public const string ICON_PLAY = "media-playback-start-symbolic";
        public const string ICON_PAUSE = "media-playback-pause-symbolic";
        public const string ICON_STOPPED = "media-playback-stop-symbolic";

        private Cancellable album_art_cancellable = new Cancellable ();
        private string prev_art_url;

        private unowned Config mpris_config;

        public MprisPlayer (MprisSource source, Config mpris_config) {
            Object (source: source);
            this.mpris_config = mpris_config;

            // TODO: Only update changed properties widgets!
            source.properties_changed.connect (properties_changed);

            // TODO: Get AppInfo!

            // Init content
            update_content ();

            /* Callbacks */

            // Shuffle
            button_shuffle.clicked.connect (() => {
                source.media_player.shuffle = button_shuffle.active;
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
                try {
                    source.media_player.previous ();
                } catch (Error e) {
                    error ("Previous Error: %s", e.message);
                }
            });
            // Next
            button_next.clicked.connect (() => {
                try {
                    source.media_player.next ();
                } catch (Error e) {
                    error ("Next Error: %s", e.message);
                }
            });
            // Play/Pause
            button_play_pause.clicked.connect (() => {
                try {
                    source.media_player.play_pause ();
                    // Wait until dbus value has updated
                    button_play_pause.sensitive = false;
                } catch (Error e) {
                    error ("PlayPause Error: %s", e.message);
                }
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
                        update_button_shuffle (metadata);
                        update_button_repeat (metadata);
                        update_button_prev (metadata);
                        update_button_forward (metadata);
                        update_button_play_pause (metadata);
                        break;
                }
            }
            debug ("Changed: %s", string.joinv (", ", changed.get_keys_as_array ()));
        }

        private void update_content () {
            HashTable<string, Variant> metadata = source.media_player.metadata;
            // Album art
            update_album_art.begin (metadata);

            // Title
            update_title (metadata);

            // Subtitle
            update_sub_title (metadata);

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

        private void update_title (HashTable<string, Variant> metadata) {
            if ("xesam:title" in metadata
                && metadata["xesam:title"].get_string () != "") {
                string str = metadata["xesam:title"].get_string ();
                title.set_text (str);
            } else {
                // TODO: Use AppInfo to get display name or regular name
                title.set_text ("Media Player");
            }
        }

        private void update_sub_title (HashTable<string, Variant> metadata) {
            // TODO: Also show artists!
            if ("xesam:album" in metadata
                && metadata["xesam:album"].get_string () != "") {
                string str = metadata["xesam:album"].get_string ();
                sub_title.set_text (str);
                sub_title.show ();
            } else {
                sub_title.set_text ("");
                sub_title.hide ();
            }
        }

        private async void update_album_art (HashTable<string, Variant> metadata) {
            if (!("mpris:artUrl" in metadata)) return;
            string url = metadata["mpris:artUrl"].get_string ();
            if (url == prev_art_url) return;
            prev_art_url = url;

            int scale = get_style_context ().get_scale ();
            // TODO: Set app .desktop icon as image as fallback

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
                warning ("Could not download album art for %s. Using fallback...",
                         source.media_player.identity);
            }
            if (pixbuf != null) {
                pixbuf = Functions.scale_round_pixbuf (pixbuf,
                                                       mpris_config.image_size,
                                                       mpris_config.image_size,
                                                       scale,
                                                       mpris_config.image_radius);
                album_art.set_from_pixbuf (pixbuf);
                album_art.get_style_context ().set_scale (1);
                return;
            }
            // TODO: SET FALLBACK!
        }

        private void update_button_shuffle (HashTable<string, Variant> metadata) {
            if (source.media_player.can_control) {
                // Shuffle check
                Variant ? shuffle = source.get_mpris_player_prop ("Shuffle");
                if (shuffle == null || !shuffle.is_of_type (VariantType.BOOLEAN)) {
                    button_shuffle.active = false;
                    button_shuffle.sensitive = false;
                    button_shuffle.hide ();
                } else {
                    button_shuffle.active = source.media_player.shuffle;
                    button_shuffle.sensitive = true;
                    button_shuffle.show ();
                }
            } else {
                button_shuffle.hide ();
            }
        }

        private void update_button_prev (HashTable<string, Variant> metadata) {
            button_prev.set_sensitive (source.media_player.can_go_previous
                                       && source.media_player.can_control);
        }

        private void update_button_play_pause (HashTable<string, Variant> metadata) {
            // TODO: Stopped
            string icon_name;
            bool check;
            switch (source.media_player.playback_status) {
                case "Playing" :
                    icon_name = ICON_PAUSE;
                    check = source.media_player.can_pause;
                    break;
                case "Paused":
                default:
                    icon_name = ICON_PLAY;
                    check = source.media_player.can_play;
                    break;
                case "Stopped":
                    icon_name = ICON_STOPPED;
                    check = source.media_player.can_play;
                    break;
            }
            button_play_pause_img.icon_name = icon_name;
            button_play_pause.sensitive = check && source.media_player.can_control;
        }

        private void update_button_forward (HashTable<string, Variant> metadata) {
            button_next.set_sensitive (source.media_player.can_go_next
                                       && source.media_player.can_control);
        }

        private void update_button_repeat (HashTable<string, Variant> metadata) {
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
                            opacity = 0.5;
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
                    button_repeat.opacity = opacity;
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
