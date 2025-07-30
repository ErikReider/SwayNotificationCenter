namespace SwayNotificationCenter {
    public class NotificationCloseButton : Adw.Bin {
        Gtk.Revealer revealer;
        Gtk.Button button;

        construct {
            valign = Gtk.Align.START;
            // TODO: Configurable
            halign = Gtk.Align.END;

            revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.CROSSFADE,
                reveal_child = false,
            };
            revealer.notify["child-revealed"].connect (() => {
                set_visible (revealer.reveal_child);
            });
            set_child (revealer);

            button = new Gtk.Button.from_icon_name ("swaync-close-symbolic") {
                has_frame = false,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
            };
            button.add_css_class ("close-button");
            button.add_css_class ("circular");
            button.clicked.connect (() => this.clicked ());
            revealer.set_child (button);
        }

        public signal void clicked ();

        public void set_reveal (bool state) {
            if (state == revealer.reveal_child) {
                set_visible (state);
                return;
            }

            if (state) {
                set_visible (true);
            }
            revealer.set_reveal_child (state);
        }

        public void set_transition_duration (uint duration) {
            revealer.set_transition_duration (duration);
        }
    }

    public enum NotificationType { CONTROL_CENTER, POPUP }

    [GtkTemplate (ui = "/org/erikreider/swaync/ui/notification.ui")]
    public class Notification : Gtk.Box {
        [GtkChild]
        unowned Gtk.Revealer revealer;
        [GtkChild]
        unowned DismissibleWidget dismissible_widget;

        [GtkChild]
        unowned Gtk.Overlay base_widget;

        [GtkChild]
        unowned Gtk.Box default_action;

        [GtkChild]
        unowned Gtk.FlowBox alt_actions_box;

        /** The default_action gesture. Allows clicks while not in swipe gesture. */
        private Gtk.GestureClick gesture;
        /** Detects when hovering over the widget */
        private Gtk.EventControllerMotion motion_controller;

        [GtkChild]
        unowned Gtk.ProgressBar progress_bar;

        [GtkChild]
        unowned IterBox base_box;

        [GtkChild]
        unowned NotificationCloseButton close_button;

        [GtkChild]
        unowned Gtk.Label summary;
        [GtkChild]
        unowned Gtk.Label time;
        [GtkChild]
        unowned Gtk.Label body;
        [GtkChild]
        unowned Gtk.Image img;
        [GtkChild]
        unowned Gtk.Image img_app_icon;
        [GtkChild]
        unowned Gtk.Picture body_image;

        // Inline Reply
        [GtkChild]
        unowned Gtk.Box inline_reply_box;
        [GtkChild]
        unowned Gtk.Entry inline_reply_entry;
        [GtkChild]
        unowned Gtk.Button inline_reply_button;

        private bool default_action_down = false;
        private bool default_action_in = false;

        private int notification_body_image_height {
            get;
            default = ConfigModel.instance.notification_body_image_height;
        }
        private int notification_body_image_width {
            get;
            default = ConfigModel.instance.notification_body_image_width;
        }

        private uint timeout_id = 0;

        public bool is_timed { get; construct; default = false; }

        public NotifyParams param { get; private set; }
        public unowned NotiDaemon noti_daemon { get; construct; }

        public NotificationType notification_type {
            get;
            construct;
            default = NotificationType.POPUP;
        }

        public uint timeout_delay { get; construct; }
        public uint timeout_low_delay { get; construct; }
        public uint timeout_critical_delay { get; construct; }

        public int transition_time { get; construct; }

        public int number_of_body_lines { get; construct; default = 10; }

        public bool has_inline_reply { get; private set; default = false; }

        private static Regex code_regex;

        private static Regex tag_regex;
        private static Regex tag_unescape_regex;
        private static Regex img_tag_regex;
        private const string[] TAGS = { "b", "u", "i" };
        private const string[] UNESCAPE_CHARS = {
            "lt;", "#60;", "#x3C;", "#x3c;", // <
            "gt;", "#62;", "#x3E;", "#x3e;", // >
            "apos;", "#39;", // '
            "quot;", "#34;", // "
            "amp;" // &
        };

        private Notification () {}

        /** Show a non-timed notification */
        public Notification.regular (NotifyParams param,
                                     NotiDaemon noti_daemon,
                                     NotificationType notification_type) {
            Object (noti_daemon: noti_daemon,
                    notification_type: notification_type);
            this.param = param;
            build_noti ();
        }

        /** Show a timed notification */
        public Notification.timed (NotifyParams param,
                                   NotiDaemon noti_daemon,
                                   NotificationType notification_type,
                                   uint timeout,
                                   uint timeout_low,
                                   uint timeout_critical) {
            Object (noti_daemon: noti_daemon,
                    notification_type: notification_type,
                    is_timed: true,
                    timeout_delay: timeout,
                    timeout_low_delay: timeout_low,
                    timeout_critical_delay: timeout_critical,
                    number_of_body_lines: 5
            );
            this.param = param;
            build_noti ();
        }

        construct {
            try {
                code_regex = new Regex ("(?<= |^)(\\d{3}(-| )\\d{3}|\\d{4,8})(?= |$|\\.|,)",
                                        RegexCompileFlags.MULTILINE);
                string joined_tags = string.joinv ("|", TAGS);
                tag_regex = new Regex ("&lt;(/?(?:%s))&gt;".printf (joined_tags));
                string unescaped = string.joinv ("|", UNESCAPE_CHARS);
                tag_unescape_regex = new Regex ("&amp;(?=%s)".printf (unescaped));
                img_tag_regex = new Regex ("<img[^>]* src=((\"([^\"]*)\")|(\'([^\']*)\'))[^>]*>");
            } catch (Error e) {
                stderr.printf ("Invalid regex: %s", e.message);
            }

            // Build the default_action gesture
            gesture = new Gtk.GestureClick ();
            default_action.add_controller (gesture);
            gesture.set_touch_only (false);
            gesture.set_exclusive (true);
            gesture.set_button (0);
            gesture.set_propagation_phase (Gtk.PropagationPhase.BUBBLE);
            gesture.pressed.connect ((_gesture, _n_press, _x, _y) => {
                default_action_in = true;
                default_action_down = true;
            });
            gesture.released.connect ((gesture, _n_press, _x, _y) => {
                // Emit released
                if (!default_action_down) return;
                default_action_down = false;
                if (default_action_in) {
                    // Close notification on middle and right button click
                    switch (gesture.get_current_button ()) {
                        default:
                        case Gdk.BUTTON_PRIMARY:
                            click_default_action ();
                            break;
                        case Gdk.BUTTON_MIDDLE:
                        case Gdk.BUTTON_SECONDARY:
                            this.close_notification ();
                            break;
                    }
                }

                Gdk.EventSequence ? sequence = gesture.get_current_sequence ();
                if (sequence == null) {
                    default_action_in = false;
                }
            });
            gesture.update.connect ((gesture, sequence) => {
                Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
                if (sequence != gesture_single.get_current_sequence ()) return;

                int width = default_action.get_width ();
                int height = default_action.get_height ();
                double x, y;

                gesture.get_point (sequence, out x, out y);
                bool in_button = (x >= 0 && y >= 0 && x < width && y < height);
                if (default_action_in != in_button) {
                    default_action_in = in_button;
                }
            });
            gesture.cancel.connect ((_gesture, _sequence) => {
                if (default_action_down) {
                    default_action_down = false;
                }
            });

            this.transition_time = ConfigModel.instance.transition_time;

            ///
            /// Signals
            ///

            default_action.unmap.connect (() => default_action_in = false);

            close_button.clicked.connect (() => close_notification ());

            motion_controller = new Gtk.EventControllerMotion ();
            base_widget.add_controller (motion_controller);
            motion_controller.enter.connect ((event) => {
                close_button.set_reveal (true);
                remove_noti_timeout ();
            });
            motion_controller.leave.connect ((controller) => {
                close_button.set_reveal (false);
                add_notification_timeout ();
            });


            // Remove notification when it has been swiped
            dismissible_widget.dismissed.connect (() => {
                remove_noti_timeout ();
                try {
                    noti_daemon.manually_close_notification (
                        param.applied_id, false);
                } catch (Error e) {
                    printerr ("Error: %s\n", e.message);
                    this.destroy ();
                }
            });

            Gtk.EventControllerKey reply_key_controller = new Gtk.EventControllerKey ();
            reply_key_controller.key_released.connect ((keyval, keycode, state) => {
                if (Gdk.keyval_name (keyval) == "Return") {
                    inline_reply_button.clicked ();
                }
            });
            inline_reply_entry.add_controller (reply_key_controller);
            inline_reply_button.clicked.connect (() => {
                string text = inline_reply_entry.get_text ().strip ();
                if (text.length == 0) return;
                noti_daemon.NotificationReplied (param.applied_id, text);
                // Dismiss notification without activating Action
                action_clicked (null);
            });

        }

        private void build_noti () {
            this.body.set_wrap (true);
            this.body.set_wrap_mode (Pango.WrapMode.WORD_CHAR);
            this.body.set_natural_wrap_mode (Gtk.NaturalWrapMode.WORD);
            this.body.set_ellipsize (Pango.EllipsizeMode.END);

            this.summary.set_wrap (false);
            this.summary.set_text (param.summary ?? param.app_name);
            this.summary.set_ellipsize (Pango.EllipsizeMode.END);

            close_button.set_transition_duration (this.transition_time);

            this.revealer.set_transition_duration (this.transition_time);

            // Changes the swipe direction depending on the notifications X position
            switch (ConfigModel.instance.positionX) {
                case PositionX.LEFT:
                    dismissible_widget.set_gesture_direction (SwipeDirection.SWIPE_LEFT);
                    break;
                default:
                case PositionX.RIGHT:
                case PositionX.CENTER:
                    dismissible_widget.set_gesture_direction (SwipeDirection.SWIPE_RIGHT);
                    break;
            }

            if (this.progress_bar.visible = param.has_synch) {
                this.progress_bar.set_fraction (param.value * 0.01);
            }

            set_body ();
            set_icon ();
            set_inline_reply ();
            set_actions ();
            set_style_urgency ();

            Timeout.add (0, () => {
                revealer.set_reveal_child (true);
                return Source.REMOVE;
            });

            remove_noti_timeout ();
            if (is_timed) {
                add_notification_timeout ();
            }
        }

        private void set_body () {
            string text = param.body ?? "";

            this.body.set_lines (this.number_of_body_lines);

            // Reset state
            body_image.hide ();

            // Removes all image tags and adds them to an array
            if (text.length > 0) {
                try {
                    // Get src paths from images
                    string[] img_paths = {};
                    MatchInfo info;
                    if (img_tag_regex.match (text, 0, out info)) {
                        do {
                            if (info == null) {
                                break;
                            }

                            // Use the first capture group and remove the start and end quote
                            string result = info.fetch (1).strip ().slice (1, -1);

                            // Replaces "~/" with $HOME
                            if (result.index_of ("~/", 0) == 0) {
                                result = Environment.get_home_dir () +
                                      result.slice (1, result.length);
                            }
                            img_paths += result;
                        } while (info.next ());
                    }

                    // Remove all images
                    text = img_tag_regex.replace (text, text.length, 0, "");

                    // Set the image if exists and is valid
                    if (img_paths.length > 0) {
                        string img = Functions.uri_to_path (img_paths[0]);
                        File file = File.new_for_path (img);
                        if (img.length > 0 && file.query_exists ()) {
                            Gdk.Texture texture = Gdk.Texture.from_file (file);
                            body_image.set_paintable (texture);
                            body_image.set_can_shrink (true);
                            body_image.set_content_fit (Gtk.ContentFit.SCALE_DOWN);
                            body_image.width_request = notification_body_image_width;
                            body_image.height_request = notification_body_image_height;
                            // Fixes the Picture taking up too much space:
                            // https://gitlab.gnome.org/GNOME/gtk/-/issues/7092
                            Gtk.LayoutManager layout = new Gtk.CenterLayout ();
                            body_image.set_layout_manager (layout);
                            body_image.show ();
                        }
                    }
                } catch (Error e) {
                    stderr.printf (e.message);
                }
            }

            // Markup
            try {
                Pango.AttrList ? attr = null;
                string ? buf = null;
                try {
                    // Try parsing without any hacks
                    Pango.parse_markup (text, -1, 0, out attr, out buf, null);
                } catch (Error e) {
                    // Default to hack if the initial markup couldn't be parsed

                    // Escapes all characters
                    string escaped = Markup.escape_text (text);
                    // Replace all valid tags brackets with <,</,> so that the
                    // markup parser only parses valid tags
                    // Ex: &lt;b&gt;BOLD&lt;/b&gt; -> <b>BOLD</b>
                    escaped = tag_regex.replace (escaped, escaped.length, 0, "<\\1>");

                    // Unescape a few characters that may have been double escaped
                    // Sending "<" in Discord would result in "&amp;lt;" without this
                    // &amp;lt; -> &lt;
                    escaped = tag_unescape_regex.replace_literal (escaped, escaped.length, 0, "&");

                    // Turns it back to markup, defaults to original if not valid
                    Pango.parse_markup (escaped, -1, 0, out attr, out buf, null);
                }

                this.body.set_text (buf);
                if (attr != null) this.body.set_attributes (attr);
            } catch (Error e) {
                stderr.printf ("Could not parse Pango markup %s: %s\n",
                               text, e.message);
                // Sets the original text
                this.body.set_text (text);
            }

            this.body.set_visible (this.body.get_text ().length > 0);
        }

        /** Returns the first code found, else null */
        private string ? parse_body_codes () {
            if (!ConfigModel.instance.notification_2fa_action) return null;
            string body = this.body.get_text ().strip ();
            if (body.length == 0) return null;

            MatchInfo info;
            var result = code_regex.match (body, RegexMatchFlags.NOTEMPTY, out info);
            string ? match = info.fetch (0);
            if (!result || match == null) return null;

            return Functions.filter_string (
                match.strip (), (c) => c.isdigit () || c.isspace ()).strip ();
        }

        public void click_default_action () {
            action_clicked (param.default_action);
        }

        public void click_alt_action (uint index) {
            if (!alt_actions_box.visible) return;

            unowned Gtk.Widget? button = null;
            int i = 0;
            for (unowned Gtk.Widget ? child = alt_actions_box.get_first_child ();
                 child != null;
                 child = child.get_next_sibling ()) {
                if (!(child is Gtk.FlowBoxChild)) {
                    continue;
                }
                unowned Gtk.FlowBoxChild f_child = (Gtk.FlowBoxChild) child;
                if (i == index) {
                    button = f_child.child;
                    break;
                }
                i++;
            }

            if (button == null) {
                return;
            } else if (button is Gtk.Button) {
                ((Gtk.Button) button).clicked ();
                return;
            }
            // Backup if the above fails
            action_clicked (param.actions.index (index));
        }

        private void action_clicked (Action ? action) {
            noti_daemon.run_scripts (param, ScriptRunOnType.ACTION);
            if (action != null
                && action.identifier != null
                && action.identifier != "") {
                // Try getting a XDG Activation token so that the application
                // can request compositor focus
                string ? token = swaync_daemon.xdg_activation.get_token (this);
                if (token != null) {
                    noti_daemon.ActivationToken (param.applied_id, token);
                }

                noti_daemon.ActionInvoked (param.applied_id, action.identifier);
                if (ConfigModel.instance.hide_on_action) {
                    try {
                        swaync_daemon.set_visibility (false);
                    } catch (Error e) {
                        print ("Error: %s\n", e.message);
                    }
                }
            }
            if (!param.resident) close_notification ();
        }

        private void set_style_urgency () {
            // Reset state
            base_box.remove_css_class ("low");
            base_box.remove_css_class ("normal");
            base_box.remove_css_class ("critical");

            switch (param.urgency) {
                case UrgencyLevels.LOW:
                    base_box.add_css_class ("low");
                    break;
                case UrgencyLevels.NORMAL:
                default:
                    base_box.add_css_class ("normal");
                    break;
                case UrgencyLevels.CRITICAL:
                    base_box.add_css_class ("critical");
                    break;
            }
        }

        private void set_inline_reply () {
            // Reset state
            inline_reply_box.hide ();
            // Only show inline replies in popup notifications if the compositor
            // supports ON_DEMAND layer shell keyboard interactivity
            if (!ConfigModel.instance.notification_inline_replies
                || (ConfigModel.instance.layer_shell
                   && !swaync_daemon.has_layer_on_demand
                   && notification_type == NotificationType.POPUP)) {
                return;
            }
            if (param.inline_reply == null) return;

            has_inline_reply = true;

            inline_reply_box.show ();

            inline_reply_entry.set_placeholder_text (
                param.inline_reply_placeholder ?? "Enter Text");
            // Set reply Button sensitivity to disabled if Entry text is empty
            inline_reply_entry.bind_property (
                "text",
                inline_reply_button, "sensitive",
                BindingFlags.SYNC_CREATE,
                (binding, srcval, ref targetval) => {
                targetval.set_boolean (((string) srcval).strip ().length > 0);
                return true;
            },
                null);

            inline_reply_button.set_label (param.inline_reply.name ?? "Reply");
        }

        private void set_actions () {
            alt_actions_box.set_visible (false);

            // Remove all of the old alt actions
            for (unowned Gtk.Widget child = alt_actions_box.get_first_child ();
                 child != null;
                 child = alt_actions_box.get_first_child ()) {
                alt_actions_box.remove (child);
            }
            alt_actions_box.set_max_children_per_line (1);

            // Check for security codes
            string ? code = parse_body_codes ();

            // Display all of the actions
            if (param.actions.length > 0 || code != null) {
                alt_actions_box.set_visible (true);

                // Add "Copy code" Action if available and copy it to clipboard when clicked
                if (code != null && code.length > 0) {
                    Gtk.FlowBoxChild flowbox_child = new Gtk.FlowBoxChild ();
                    flowbox_child.add_css_class ("notification-action");
                    alt_actions_box.append (flowbox_child);

                    Gtk.Button action_button = new Gtk.Button.with_label (
                        "COPY \"%s\"".printf (code));
                    action_button.clicked.connect (() => {
                        // Copy to clipboard
                        get_clipboard ().set_text (code);
                        // Dismiss notification
                        action_clicked (null);
                    });
                    action_button.set_can_focus (false);
                    flowbox_child.set_child (action_button);
                }

                int max_children_per_line = 0;
                // Add notification specified actions
                foreach (var action in param.actions.data) {
                    max_children_per_line++;
                    Gtk.FlowBoxChild flowbox_child = new Gtk.FlowBoxChild ();
                    flowbox_child.add_css_class ("notification-action");
                    alt_actions_box.append (flowbox_child);

                    Gtk.Button action_button = new Gtk.Button.with_label (action.name);
                    action_button.clicked.connect (() => action_clicked (action));
                    action_button.set_can_focus (false);
                    flowbox_child.set_child (action_button);
                }
                alt_actions_box.set_max_children_per_line (max_children_per_line.clamp (1, 7));
            }
        }

        public void set_time () {
            if (ConfigModel.instance.relative_timestamps) {
                this.time.set_text (get_relative_time ());
            } else {
                this.time.set_text (get_iso8601_time ());
            }
        }

        private string get_relative_time () {
            string value = "";

            double diff = (get_real_time () * 0.000001) - param.time;
            double secs = diff / 60;
            double hours = secs / 60;
            double days = hours / 24;
            if (secs < 1) {
                value = "Now";
            } else if (secs >= 1 && hours < 1) {
                // 1m - 1h
                var val = Math.floor (secs);
                value = val.to_string () + " min";
                if (val > 1) value += "s";
                value += " ago";
            } else if (hours >= 1 && hours < 24) {
                // 1h - 24h
                var val = Math.floor (hours);
                value = val.to_string () + " hour";
                if (val > 1) value += "s";
                value += " ago";
            } else {
                // Days
                var val = Math.floor (days);
                value = val.to_string () + " day";
                if (val > 1) value += "s";
                value += " ago";
            }
            return value;
        }

        private string get_iso8601_time () {
            var dtime = new DateTime.from_unix_local (param.time);
            return dtime.format_iso8601 ();
        }

        public void close_notification (bool is_timeout = false) {
            remove_noti_timeout ();
            this.revealer.set_reveal_child (false);
            Timeout.add (this.transition_time, () => {
                try {
                    noti_daemon.manually_close_notification (param.applied_id,
                                                             is_timeout);
                } catch (Error e) {
                    print ("Error: %s\n", e.message);
                    this.destroy ();
                }
                return Source.REMOVE;
            });
        }

        public void replace_notification (NotifyParams new_params) {
            this.param = new_params;
            build_noti ();
        }

        private void set_icon () {
            img.clear ();
            img.set_visible (true);
            img_app_icon.clear ();
            img_app_icon.set_visible (true);

            Icon ? app_icon_name = null;
            string ? app_icon_uri = null;
            if (param.desktop_app_info != null) {
                app_icon_name = param.desktop_app_info.get_icon ();
            }
            if (param.app_icon != null && param.app_icon != "") {
                app_icon_uri = param.app_icon;
            }

            var image_visibility = ConfigModel.instance.image_visibility;
            if (image_visibility == ImageVisibility.NEVER) {
                img.set_visible (false);
                img_app_icon.set_visible (false);
                return;
            }

            int notification_icon_size = ConfigModel.instance.notification_icon_size.clamp (-1, int.MAX);
            if (notification_icon_size < 1) {
                notification_icon_size = -1;
            }
            img.set_pixel_size (notification_icon_size);
            img.height_request = notification_icon_size;
            img.width_request = notification_icon_size;
            int app_icon_size = (notification_icon_size / 3).clamp (-1, int.MAX);
            if (app_icon_size < 1) {
                app_icon_size = -1;
            }
            img_app_icon.set_pixel_size (app_icon_size);

            bool img_path_is_theme_icon = false;
            bool img_path_exists = File.new_for_uri (param.image_path ?? "").query_exists ();
            if (param.image_path != null && !img_path_exists) {
                // Check if it's not a URI
                img_path_exists = File.new_for_path (
                    param.image_path ?? "").query_exists ();

                // Check if it's a freedesktop.org-compliant icon
                if (!img_path_exists) {
                    unowned Gtk.IconTheme icon_theme = Gtk.IconTheme.get_for_display (get_display ());
                    img_path_exists = icon_theme.has_icon (param.image_path);
                    img_path_is_theme_icon = img_path_exists;
                }
            }
            bool app_icon_exists = File.new_for_uri (app_icon_uri ?? "").query_exists ();
            if (app_icon_uri != null && !app_icon_exists) {
                // Check if it's not a URI
                app_icon_exists = File.new_for_path (app_icon_uri ?? "").query_exists ();
            }

            // Set the main image to the provided image
            if (param.image_data.is_initialized) {
                Functions.set_image_data (param.image_data, img);
            } else if (param.image_path != null &&
                       param.image_path != "" &&
                       img_path_exists) {
                Functions.set_image_uri (param.image_path, img,
                                         img_path_exists,
                                         img_path_is_theme_icon);
            } else if (param.icon_data.is_initialized) {
                Functions.set_image_data (param.icon_data, img);
            }

            if (img.storage_type == Gtk.ImageType.EMPTY) {
                // Get the app icon
                if (app_icon_uri != null) {
                    Functions.set_image_uri (app_icon_uri, img,
                                              app_icon_exists);
                } else if (app_icon_name != null) {
                    img.set_from_gicon (app_icon_name);
                } else if (image_visibility == ImageVisibility.ALWAYS) {
                    // Default icon
                    img.set_from_icon_name ("image-missing");
                } else {
                    img.set_visible (false);
                }
            } else {
                // We only set the app icon if the main image is set
                if (app_icon_uri != null) {
                    Functions.set_image_uri (app_icon_uri, img_app_icon,
                                             app_icon_exists);
                } else if (app_icon_name != null) {
                    img_app_icon.set_from_gicon (app_icon_name);
                }
            }
        }

        public void add_notification_timeout () {
            if (!this.is_timed) return;

            // Removes the previous timeout
            remove_noti_timeout ();

            uint timeout;
            switch (param.urgency) {
                case UrgencyLevels.LOW:
                    timeout = timeout_low_delay * 1000;
                    break;
                case UrgencyLevels.NORMAL:
                default:
                    timeout = timeout_delay * 1000;
                    break;
                case UrgencyLevels.CRITICAL:
                    // Critical notifications should not automatically expire.
                    // Ignores the notifications expire_timeout.
                    if (timeout_critical_delay == 0) return;
                    timeout = timeout_critical_delay * 1000;
                    break;
            }
            uint ms = param.expire_timeout > 0 ? param.expire_timeout : timeout;
            if (ms <= 0) return;
            timeout_id = Timeout.add (ms, () => {
                close_notification (true);
                return Source.REMOVE;
            });
        }

        public void remove_noti_timeout () {
            if (timeout_id > 0) {
                Source.remove (timeout_id);
                timeout_id = 0;
            }
        }
    }
}
