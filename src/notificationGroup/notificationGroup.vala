namespace SwayNotificationCenter {
    public class NotificationGroup : Gtk.ListBoxRow {
        const string STYLE_CLASS_URGENT = "critical";
        const string STYLE_CLASS_COLLAPSED = "collapsed";

        public string name_id;

        private NotificationCloseButton close_button;
        private DismissibleWidget dismissible;
        private ExpandableGroup group;
        private Gtk.Revealer revealer = new Gtk.Revealer ();
        private Gtk.Image app_icon;
        private Gtk.Label app_label;

        private Gtk.EventControllerMotion motion_controller;
        private Gtk.GestureClick gesture;
        private bool gesture_down = false;
        private bool gesture_in = false;

        private HashTable<uint32, bool> urgent_notifications
            = new HashTable<uint32, bool> (direct_hash, direct_equal);

        public signal void on_expand_change (bool state);

        public NotificationGroup (string name_id, string display_name,
                                  Gtk.Viewport viewport) {
            this.name_id = name_id;
            add_css_class ("notification-group");

            dismissible = new DismissibleWidget ();
            dismissible.dismissed.connect (close_all_notifications);
            set_child (dismissible);

            Gtk.Overlay overlay = new Gtk.Overlay ();
            overlay.set_can_focus (false);
            dismissible.child = overlay;

            Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.set_hexpand (true);
            overlay.set_child (box);

            close_button = new NotificationCloseButton ();
            close_button.clicked.connect (close_all_notifications);
            close_button.add_css_class ("notification-group-close-button");
            overlay.add_overlay (close_button);

            revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_UP);
            revealer.set_reveal_child (false);
            revealer.set_transition_duration (Constants.ANIMATION_DURATION);

            // Add top controls
            Gtk.Box controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            Gtk.Box end_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            end_box.set_halign (Gtk.Align.END);
            end_box.add_css_class ("notification-group-buttons");

            // Collapse button
            Gtk.Button collapse_button = new Gtk.Button.from_icon_name (
                "swaync-collapse-symbolic");
            collapse_button.add_css_class ("circular");
            collapse_button.add_css_class ("notification-group-collapse-button");
            collapse_button.set_halign (Gtk.Align.END);
            collapse_button.set_valign (Gtk.Align.CENTER);
            collapse_button.clicked.connect (() => {
                set_expanded (false);
                on_expand_change (false);
            });
            end_box.append (collapse_button);

            // Close all button
            Gtk.Button close_all_button = new Gtk.Button.from_icon_name (
                "swaync-close-symbolic");
            close_all_button.add_css_class ("circular");
            close_all_button.add_css_class ("notification-group-close-all-button");
            close_all_button.set_halign (Gtk.Align.END);
            close_all_button.set_valign (Gtk.Align.CENTER);
            close_all_button.clicked.connect (() => {
                close_all_notifications ();
                on_expand_change (false);
            });
            end_box.append (close_all_button);

            // Group name label
            Gtk.Box start_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            start_box.set_halign (Gtk.Align.START);
            start_box.set_hexpand (true);
            start_box.add_css_class ("notification-group-headers");
            // App Icon
            app_icon = new Gtk.Image ();
            app_icon.set_valign (Gtk.Align.CENTER);
            app_icon.add_css_class ("notification-group-icon");
            start_box.append (app_icon);
            // App Label
            app_label = new Gtk.Label (display_name);
            app_label.xalign = 0;
            app_label.set_ellipsize (Pango.EllipsizeMode.END);
            app_label.add_css_class ("title-1");
            app_label.add_css_class ("notification-group-header");
            start_box.append (app_label);

            controls_box.prepend (start_box);
            controls_box.append (end_box);
            revealer.set_child (controls_box);
            box.append (revealer);

            set_activatable (false);

            group = new ExpandableGroup (viewport, Constants.ANIMATION_DURATION);
            box.append (group);

            set_classes ();

            /*
             * Handling of group presses
             */
            gesture = new Gtk.GestureClick ();
            box.add_controller (gesture);
            gesture.set_touch_only (false);
            gesture.set_exclusive (true);
            gesture.set_button (Gdk.BUTTON_PRIMARY);
            gesture.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
            gesture.pressed.connect ((_gesture, _n_press, x, y) => {
                gesture_in = true;
                gesture_down = true;
            });
            gesture.released.connect ((gesture, _n_press, _x, _y) => {
                // Emit released
                if (!gesture_down) {
                    return;
                }
                gesture_down = false;
                if (gesture_in) {
                    bool single_noti = only_single_notification ();
                    if (!group.is_expanded && !single_noti) {
                        set_expanded (true);
                        on_expand_change (true);
                    }
                    group.set_sensitive (single_noti || group.is_expanded);
                }

                Gdk.EventSequence ?sequence = gesture.get_current_sequence ();
                if (sequence == null) {
                    gesture_in = false;
                }
            });
            gesture.update.connect ((gesture, sequence) => {
                Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
                if (sequence != gesture_single.get_current_sequence ()) {
                    return;
                }

                int width = get_width ();
                int height = get_height ();
                double x, y;

                gesture.get_point (sequence, out x, out y);
                bool intersects = (x >= 0 && y >= 0 && x < width && y < height);
                if (gesture_in != intersects) {
                    gesture_in = intersects;
                }
            });
            gesture.cancel.connect ((gesture, sequence) => {
                if (gesture_down) {
                    gesture_down = false;
                }
            });

            /*
             * Handling of group hover
             */
            motion_controller = new Gtk.EventControllerMotion ();
            this.add_controller (motion_controller);
            motion_controller.motion.connect ((event) => {
                close_button.set_reveal (!group.is_expanded && !only_single_notification ());
            });
            motion_controller.leave.connect ((controller) => {
                close_button.set_reveal (false);
            });
        }

        private void set_classes () {
            remove_css_class (STYLE_CLASS_COLLAPSED);
            if (!group.is_expanded) {
                if (!has_css_class (STYLE_CLASS_COLLAPSED)) {
                    add_css_class (STYLE_CLASS_COLLAPSED);
                }
            }
        }

        private void set_icon () {
            if (is_empty ()) {
                return;
            }

            unowned Notification first = (Notification) group.widgets.first ().data;
            unowned NotifyParams param = first.param;
            // Get the app icon
            Icon ?icon = null;
            if (param.desktop_app_info != null
                && (icon = param.desktop_app_info.get_icon ()) != null) {
                app_icon.set_from_gicon (icon);
            } else {
                app_icon.set_from_icon_name ("application-x-executable-symbolic");
            }
        }

        /// Returns if there's more than one notification
        public bool only_single_notification () {
            return group.widgets.nth_data (0) != null && group.widgets.nth_data (1) == null;
        }

        public void set_expanded (bool state) {
            group.set_expanded (state);
            revealer.set_reveal_child (state);
            // Change CSS Class
            if (parent != null) {
                set_classes ();
            }

            group.set_sensitive (only_single_notification () || group.is_expanded);
            dismissible.set_can_dismiss (!state);
        }

        public bool toggle_expanded () {
            bool state = !group.is_expanded;
            set_expanded (state);
            return state;
        }

        public void add_notification (Notification noti) {
            if (noti.param.urgency == UrgencyLevels.CRITICAL) {
                urgent_notifications.insert (noti.param.applied_id, true);
                if (!has_css_class (STYLE_CLASS_URGENT)) {
                    add_css_class (STYLE_CLASS_URGENT);
                }
            }
            group.add (noti);
            if (!only_single_notification ()) {
                if (!group.is_expanded) {
                    group.set_sensitive (false);
                }
            } else {
                set_icon ();
            }
        }

        public void remove_notification (Notification noti) {
            urgent_notifications.remove (noti.param.applied_id);
            if (urgent_notifications.length == 0) {
                remove_css_class (STYLE_CLASS_URGENT);
            }
            group.remove (noti);
            if (only_single_notification ()) {
                set_expanded (false);
                on_expand_change (false);
            }
        }

        public List<weak Gtk.Widget> get_notifications () {
            return group.widgets.copy ();
        }

        public unowned Notification ?get_latest_notification () {
            return (Notification ?) group.widgets.first ().data;
        }

        public int64 get_time () {
            if (group.widgets.is_empty ()) {
                return -1;
            }
            return ((Notification) group.widgets.first ().data).param.time;
        }

        public bool get_is_urgent () {
            return urgent_notifications.length > 0;
        }

        public uint get_num_notifications () {
            return group.widgets.length ();
        }

        public bool is_empty () {
            return group.widgets.is_empty ();
        }

        public void close_all_notifications () {
            close_button.set_reveal (false);
            urgent_notifications.remove_all ();
            foreach (unowned Gtk.Widget widget in group.widgets) {
                var noti = (Notification) widget;
                if (noti != null) {
                    noti.close_notification (false);
                }
            }
        }

        public void update () {
            set_icon ();
            foreach (unowned Gtk.Widget widget in group.widgets) {
                var noti = (Notification) widget;
                if (noti != null) {
                    noti.set_time ();
                }
            }
        }

        public float get_relative_y (Gtk.Widget parent) {
            Graphene.Point point = Graphene.Point.zero ();
            Graphene.Point dest_point;
            compute_point (parent, point, out dest_point);
            return dest_point.y;
        }
    }
}
