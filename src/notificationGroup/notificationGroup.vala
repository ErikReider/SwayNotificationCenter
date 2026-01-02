namespace SwayNotificationCenter {
    public enum NotificationGroupState {
        EMPTY = 0,
        SINLGE = 1,
        MANY = 2;
    }

    public class NotificationGroup : Gtk.ListBoxRow {
        public string name_id;

        public Gee.HashMap<uint32, unowned Notification> notification_ids {
            get;
            private set;
            default = new Gee.HashMap<uint32, unowned Notification> ();
        }

        public NotificationGroupState state {
            get; private set; default = NotificationGroupState.EMPTY;
        }

        public bool dismissed { get; private set; default = false; }
        public bool dismissed_by_swipe { get; private set; default = false; }

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

        private Gee.HashSet<uint32> urgent_notifications = new Gee.HashSet<uint32> ();

        // Remove animation
        private AnimationValueTarget animation_target;
        private Adw.TimedAnimation remove_animation;
        private ulong remove_animation_done_id = 0;

        public signal void on_expand_change (bool state);

        public NotificationGroup (string name_id, string display_name,
                                  Gtk.Viewport viewport) {
            this.name_id = name_id;
            add_css_class ("notification-group");

            // Remove Animation
            animation_target = new AnimationValueTarget (1.0f, animation_value_changed);
            remove_animation = new Adw.TimedAnimation (this, 1.0, 0.0,
                                                       Constants.ANIMATION_DURATION,
                                                       animation_target.get_animation_target ());
            remove_animation.set_easing (Adw.Easing.EASE_IN_OUT_CUBIC);

            dismissible = new DismissibleWidget ();
            dismissible.dismissed.connect (() => {
                dismissed_by_swipe = true;
                request_dismiss_all_notifications ();
            });
            set_child (dismissible);

            Gtk.Overlay overlay = new Gtk.Overlay ();
            overlay.set_can_focus (false);
            dismissible.child = overlay;

            Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.set_hexpand (true);
            overlay.set_child (box);

            close_button = new NotificationCloseButton ();
            close_button.clicked.connect (request_dismiss_all_notifications);
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
                request_dismiss_all_notifications ();
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
            group.notify["is-expanded"].connect (update_state);
            box.append (group);

            update_state ();

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
                    if (!group.is_expanded && state == NotificationGroupState.MANY) {
                        set_expanded (true);
                        on_expand_change (true);
                    }
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
                close_button.set_reveal (!group.is_expanded &&
                                         state == NotificationGroupState.MANY);
            });
            motion_controller.leave.connect ((controller) => {
                close_button.set_reveal (false);
            });
        }

        private void animation_value_changed (double progress) {
            queue_resize ();
        }

        private async bool play_remove_animation (bool transition) {
            if (remove_animation_done_id > 0) {
                // Already running animation
                return false;
            }

            set_can_focus (false);
            set_can_target (false);

            if (get_mapped () && transition) {
                remove_animation_done_id = remove_animation.done.connect ((e) => {
                    play_remove_animation.callback ();
                });
                remove_animation.value_from
                    = remove_animation.state == Adw.AnimationState.PLAYING
                        ? animation_target.progress : 1.0;
                remove_animation.value_to = 0.0;
                remove_animation.play ();
                yield;
            } else {
                animation_value_changed (0.0);
            }

            if (remove_animation_done_id > 0) {
                remove_animation.disconnect (remove_animation_done_id);
                remove_animation_done_id = 0;
            }
            // Fixes the animation keeping a reference of the widget
            remove_animation = null;

            return true;
        }

        protected override void snapshot (Gtk.Snapshot snapshot) {
            if (!base.should_layout ()) {
                return;
            }

            snapshot.push_opacity (animation_target.progress);
            base.snapshot (snapshot);
            snapshot.pop ();
        }

        private void update_state () {
            state = group.n_children >
                NotificationGroupState.SINLGE ? NotificationGroupState.MANY :
                (NotificationGroupState) group.n_children;

            group.set_sensitive (!dismissed &&
                                 (state < NotificationGroupState.MANY || group.is_expanded));

            // Set CSS classes
            const string STYLE_CLASS_URGENT = "critical";
            const string STYLE_CLASS_COLLAPSED = "collapsed";
            if (group.is_expanded) {
                remove_css_class (STYLE_CLASS_COLLAPSED);
            } else if (!has_css_class (STYLE_CLASS_COLLAPSED)) {
                add_css_class (STYLE_CLASS_COLLAPSED);
            }
            if (urgent_notifications.is_empty) {
                remove_css_class (STYLE_CLASS_URGENT);
            } else if (!has_css_class (STYLE_CLASS_URGENT)) {
                add_css_class (STYLE_CLASS_URGENT);
            }
        }

        private void set_icon () {
            if (state == NotificationGroupState.EMPTY) {
                return;
            }

            unowned Notification ?latest = get_latest_notification ();
            // Get the app icon
            Icon ?icon = null;
            if (latest != null && latest.param.desktop_app_info != null
                && (icon = latest.param.desktop_app_info.get_icon ()) != null) {
                app_icon.set_from_gicon (icon);
            } else {
                app_icon.set_from_icon_name ("application-x-executable-symbolic");
            }
        }

        private unowned Notification ?find_notification (uint32 id) {
            unowned Notification ?notification = notification_ids.get (id);
            if (notification == null || notification.param.applied_id != id) {
                return null;
            }
            return notification;
        }

        public void set_expanded (bool state) {
            if (dismissed) {
                state = false;
            }
            group.set_expanded (state);
            revealer.set_reveal_child (state);
            dismissible.set_can_dismiss (!state);
        }

        public bool toggle_expanded () {
            bool state = !group.is_expanded;
            set_expanded (state);
            return state;
        }

        public void add_notification (Notification noti) {
            if (noti.param.urgency == UrgencyLevels.CRITICAL) {
                urgent_notifications.add (noti.param.applied_id);
            }
            group.add (noti);
            notification_ids.set (noti.param.applied_id, noti);

            update_state ();
            set_icon ();
        }

        public bool replace_notification (uint32 id, NotifyParams new_params) {
            unowned Notification ?notification = find_notification (id);
            if (notification == null) {
                return false;
            }
            notification_ids.unset (id);
            notification_ids.set (new_params.applied_id, notification);
            notification.replace_notification (new_params);
            return true;
        }

        public async bool remove_notification (uint32 id) {
            update_state ();

            unowned Notification ?notification = find_notification (id);
            if (notification == null) {
                warn_if_reached ();
                return false;
            }

            urgent_notifications.remove (notification.param.applied_id);
            notification_ids.unset (notification.param.applied_id);
            notification.remove_noti_timeout ();

            // Only animate individual notifications when there are more than one,
            // otherwise, animate the whole group (collapsed single-notification)
            if (state == NotificationGroupState.MANY) {
                yield notification.remove_notification (!dismissed_by_swipe);
            } else if (state == NotificationGroupState.SINLGE) {
                dismissed = true;
                if (!yield play_remove_animation (!notification.dismissed_by_swipe)) {
                    debug ("Trying to play group removal animation twice. Ignoring");
                    return false;
                }
            } else {
                // No notifications to remove, bug.
                warn_if_reached ();
            }
            group.remove (notification);

            update_state ();
            if (state == NotificationGroupState.SINLGE) {
                set_expanded (false);
                on_expand_change (false);
            }
            return true;
        }

        public async bool remove_all_notifications (bool transition) {
            dismissed = true;
            close_button.set_reveal (false);
            urgent_notifications.clear ();
            notification_ids.clear ();

            // Skip animation if the notification was dismissed by swipe
            bool dismissed_by_swipe = this.dismissed_by_swipe;
            if (state == NotificationGroupState.SINLGE) {
                unowned Notification ?noti = (Notification ?) group.get_first_widget ();
                if (noti != null) {
                    dismissed_by_swipe |= noti.dismissed_by_swipe;
                }
            }

            if (group.is_empty ()) {
                debug ("Skiping removal of all notifications as the group is already empty");
                return false;
            }

            if (!yield play_remove_animation (transition && !dismissed_by_swipe)) {
                debug ("Trying to play group removal animation twice. Ignoring");
                return false;
            }

            group.remove_all ();
            return true;
        }

        public void request_dismiss_all_notifications () {
            if (dismissed) {
                return;
            }
            dismissed = true;
            noti_daemon.request_dismiss_notification_group (name_id, notification_ids.keys,
                                                            ClosedReasons.DISMISSED);
        }

        /** Gets the latest, non-dismissed notification */
        public unowned Notification ?get_latest_notification () {
            return (Notification ?) group.get_first_widget ((widget) => {
                unowned Notification ?notification = (Notification ?) widget;
                return notification != null && !notification.dismissed;
            });
        }

        public int64 get_time () {
            unowned Notification ?notification = get_latest_notification ();
            if (notification_ids.is_empty || notification == null) {
                return -1;
            }
            return notification.param.time;
        }

        public bool get_is_urgent () {
            return !urgent_notifications.is_empty;
        }

        public uint get_num_notifications () {
            return group.n_children;
        }

        public void update () {
            set_icon ();
            foreach (unowned Notification ?notification in notification_ids.values) {
                if (notification != null) {
                    notification.set_time ();
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
