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

        private Gdk.Pixbuf ? album_art_pixbuf = null;
        private Granite.Drawing.BufferSurface ? blurred_cover_surface = null;

        private unowned Config mpris_config;

        public signal void content_updated ();

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
            album_art.set_pixel_size (mpris_config.image_size);
        }

        public void before_destroy () {
            source.properties_changed.disconnect (properties_changed);
        }

        public override bool draw (Cairo.Context cr) {
            unowned Gdk.Window ? window = get_window ();
            if (!mpris_config.blur || window == null ||
                !(album_art_pixbuf is Gdk.Pixbuf)) {
                return base.draw (cr);
            }

            const double DEGREES = Math.PI / 180.0;
            unowned Gtk.StyleContext style_ctx = this.get_style_context ();
            unowned Gtk.StateFlags state = style_ctx.get_state ();
            Gtk.Border border = style_ctx.get_border (state);
            Gtk.Border margin = style_ctx.get_margin (state);
            Value radius_value = style_ctx.get_property (
                Gtk.STYLE_PROPERTY_BORDER_RADIUS, state);
            int radius = 0;
            if (!radius_value.holds (Type.INT) ||
                (radius = radius_value.get_int ()) == 0) {
                radius = mpris_config.image_radius;
            }
            int scale = style_ctx.get_scale ();
            int width = get_allocated_width ()
                        - margin.left - margin.right
                        - border.left - border.right;
            int height = get_allocated_height ()
                        - margin.top - margin.bottom
                        - border.top - border.bottom;

            cr.save ();
            cr.new_sub_path ();
            // Top Right
            cr.arc (width - radius + margin.right,
                    radius + margin.top,
                    radius, -90 * DEGREES, 0 * DEGREES);
            // Bottom Right
            cr.arc (width - radius + margin.right,
                    height - radius + margin.bottom,
                    radius, 0 * DEGREES, 90 * DEGREES);
            // Bottom Left
            cr.arc (radius + margin.left,
                    height - radius + margin.bottom,
                    radius, 90 * DEGREES, 180 * DEGREES);
            // Top Left
            cr.arc (radius + margin.left,
                    radius + margin.top,
                    radius, 180 * DEGREES, 270 * DEGREES);
            cr.close_path ();

            cr.set_source_rgba (0, 0, 0, 0);
            cr.clip ();

            // Draw blurred player background
            if (blurred_cover_surface == null
                || blurred_cover_surface.width != width
                || blurred_cover_surface.height != height) {
                var buffer = new Granite.Drawing.BufferSurface (width, height);
                Cairo.Surface surface = Functions.scale_pixbuf (
                    album_art_pixbuf, width, height, scale);

                buffer.context.set_source_surface (surface, 0, 0);
                buffer.context.paint ();
                buffer.fast_blur (8, 2);
                blurred_cover_surface = buffer;
            }
            cr.set_source_surface (blurred_cover_surface.surface, margin.left, margin.top);
            cr.paint ();

            cr.restore ();

            return base.draw (cr);
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

            // Emit signal
            content_updated ();

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

                // Cancel previous download, reset the state and download again
                album_art_cancellable.cancel ();
                album_art_cancellable.reset ();
                try {
                    File file = File.new_for_uri (url);
                    InputStream stream = yield file.read_async (Priority.DEFAULT,
                                                                album_art_cancellable);

                    this.album_art_pixbuf = yield new Gdk.Pixbuf.from_stream_async (
                        stream, album_art_cancellable);
                } catch (Error e) {
                    debug ("Could not download album art for %s. Using fallback...",
                           source.media_player.identity);
                    this.album_art_pixbuf = null;
                }
                if (this.album_art_pixbuf != null) {
                    unowned Gtk.StyleContext style_ctx = album_art.get_style_context ();
                    Value br_value =
                        style_ctx.get_property (Gtk.STYLE_PROPERTY_BORDER_RADIUS,
                                                style_ctx.get_state ());
                    int radius = 0;
                    if (!br_value.holds (Type.INT) ||
                        (radius = br_value.get_int ()) == 0) {
                        radius = mpris_config.image_radius;
                    }
                    var surface = Functions.scale_pixbuf (this.album_art_pixbuf,
                                                          mpris_config.image_size,
                                                          mpris_config.image_size,
                                                          scale);
                    this.album_art_pixbuf = Gdk.pixbuf_get_from_surface (surface,
                                                                         0, 0,
                                                                         mpris_config.image_size,
                                                                         mpris_config.image_size);
                    this.blurred_cover_surface = null;
                    surface = Functions.round_surface (surface,
                                                       mpris_config.image_size,
                                                       mpris_config.image_size,
                                                       scale,
                                                       radius);
                    var pix_buf = Gdk.pixbuf_get_from_surface (surface,
                                                               0, 0,
                                                               mpris_config.image_size,
                                                               mpris_config.image_size);
                    surface.finish ();
                    album_art.set_from_pixbuf (pix_buf);
                    album_art.get_style_context ().set_scale (1);
                    this.queue_draw ();

                    return;
                }
            }

            this.album_art_pixbuf = null;
            this.blurred_cover_surface = null;
            // Get the app icon
            Icon ? icon = null;
            if (desktop_entry is DesktopAppInfo) {
                icon = desktop_entry.get_icon ();
            }
            Gtk.IconInfo ? icon_info = null;
            if (icon != null) {
                album_art.set_from_gicon (icon, Gtk.IconSize.INVALID);
                icon_info = Gtk.IconTheme.get_default ().lookup_by_gicon (icon,
                                                                          mpris_config.image_size,
                                                                          Gtk.IconLookupFlags.USE_BUILTIN);
            } else {
                // Default icon
                string icon_name = "audio-x-generic-symbolic";
                album_art.set_from_icon_name (icon_name,
                                              Gtk.IconSize.INVALID);
                icon_info = Gtk.IconTheme.get_default ().lookup_icon (icon_name,
                                                                      mpris_config.image_size,
                                                                      Gtk.IconLookupFlags.USE_BUILTIN);
            }

            if (icon_info != null) {
                try {
                    this.album_art_pixbuf = icon_info.load_icon ();
                } catch (Error e) {
                    warning ("Could not load icon: %s", e.message);
                }
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
