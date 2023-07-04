namespace SwayNotificationCenter {
    public enum NotificationType { CONTROL_CENTER, POPUP }

    public class Notification : Gtk.Widget {
        Gtk.Revealer revealer;

        DismissibleWidget dismissible_widget;

        NotificationContent notification_content;

        /** The default_action gesture. Allows clicks while not in swipe gesture. */
        public Gtk.EventControllerFocus focus_event = new Gtk.EventControllerFocus ();

        private int notification_body_image_height {
            get;
            default = ConfigModel.instance.notification_body_image_height;
        }
        private int notification_body_image_width {
            get;
            default = ConfigModel.instance.notification_body_image_width;
        }

        private uint timeout_id = 0;

        public NotifyParams param { get; private set; }
        public NotiDaemon noti_daemon { get; private set; }

        public NotificationType notification_type {
            get;
            private set;
            default = NotificationType.POPUP;
        }

        public uint timeout_delay { get; private set; }
        public uint timeout_low_delay { get; private set; }
        public uint timeout_critical_delay { get; private set; }

        public int transition_time {
            get;
            private set;
            default = ConfigModel.instance.transition_time;
        }

        public bool has_inline_reply {
            get { return notification_content.has_inline_reply; }
        }

        public bool is_constructed { get; private set; default = false; }

        public Notification () {
            add_css_class ("notification-row");
            (revealer = new Gtk.Revealer () {
                reveal_child = false,
                // TODO: Add config option?
                transition_type = Gtk.RevealerTransitionType.CROSSFADE
            }).set_parent (this);
            notification_content = new NotificationContent (this);
            dismissible_widget = new DismissibleWidget (notification_content);
            revealer.set_child (dismissible_widget);

            add_controller (focus_event);

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
        }

        public void construct_notification (NotifyParams param,
                                            NotiDaemon noti_daemon,
                                            NotificationType notification_type) {
            if (is_constructed) {
                // TODO: remove this
                int height = get_allocated_height ();
                if (height > 0) set_size_request (-1, height);
                queue_resize ();
                return;
            }

            this.param = param;
            this.noti_daemon = noti_daemon;
            this.notification_type = notification_type;

            // Changes the swipe direction depending on the notifications X position
            PositionX pos_x = PositionX.NONE;
            if (notification_type == NotificationType.CONTROL_CENTER)
                pos_x = ConfigModel.instance.control_center_positionX;
            if (pos_x == PositionX.NONE) pos_x = ConfigModel.instance.positionX;
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

            this.timeout_delay = ConfigModel.instance.timeout;
            this.timeout_low_delay = ConfigModel.instance.timeout_low;
            this.timeout_critical_delay = ConfigModel.instance.timeout_critical;

            this.transition_time = ConfigModel.instance.transition_time;

            this.revealer.set_transition_duration (transition_time);
            if (param.replaces) {
                this.revealer.set_reveal_child (true);
            } else {
                // Show the reveal transition when the notification appears
                Idle.add (() => {
                    this.revealer.set_reveal_child (true);
                    return Source.REMOVE;
                });
            }

            notification_content.build_notification ();

            if (notification_type == NotificationType.POPUP) {
                add_notification_timeout ();
            }

            is_constructed = true;
        }

        /**
         * Overrides
         */

        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void measure (Gtk.Orientation orientation,
                                      int for_size,
                                      out int minimum, out int natural,
                                      out int minimum_baseline, out int natural_baseline) {
            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;

            // Force recomputing the allocated size of the wrapped GTK label in the body.
            // `queue_resize` alone DOES NOT WORK because it does not properly invalidate
            // the cache, this is a GTK bug!
            // See https://gitlab.gnome.org/GNOME/gtk/-/issues/2556
            // , https://gitlab.gnome.org/GNOME/gtk/-/issues/5868
            // , and https://gitlab.gnome.org/GNOME/gtk/-/issues/5885
            // TODO: Use a default Bin layout_manager when this issue is fixed
            notification_content.refresh_body_height ();

            // This works for some reason...
            // this.queue_resize ();

            int child_min = 0;
            int child_nat = 0;
            int child_min_baseline = -1;
            int child_nat_baseline = -1;

            get_first_child ().measure (orientation, for_size,
                                        out child_min, out child_nat,
                                        out child_min_baseline, out child_nat_baseline);

            minimum = int.max (minimum, child_min);
            natural = int.max (natural, child_nat);

            if (child_min_baseline > -1) {
                minimum_baseline = int.max (minimum_baseline, child_min_baseline);
            }
            if (child_nat_baseline > -1) {
                natural_baseline = int.max (natural_baseline, child_nat_baseline);
            }
        }

        public override void size_allocate (int width, int height, int baseline) {
            Gtk.Widget child = get_first_child ();
            if (!child.should_layout ()) return;
            child.allocate (width, height, baseline, null);
        }

        public void close_notification (bool is_timeout = false) {
            remove_noti_timeout ();
            this.revealer.set_reveal_child (false);
            Timeout.add (this.transition_time, () => {
                try {
                    noti_daemon.manually_close_notification (param.applied_id,
                                                             is_timeout);
                } catch (Error e) {
                    printerr ("Error: %s\n", e.message);
                    this.destroy ();
                }
                return Source.REMOVE;
            });
        }

        public void add_notification_timeout () {
            if (notification_type != NotificationType.POPUP) return;

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

        /** Forces the EventBox to reload its style_context #27 */
        public void reload_style_context () {
            // overlay.get_style_context ().changed ();
            // default_action.get_style_context ().changed ();
        }

        public void set_time () {
            notification_content.set_time ();
        }
    }
}
