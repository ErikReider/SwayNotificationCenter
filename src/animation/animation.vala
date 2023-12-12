namespace SwayNotificationCenter {
    public class Animation : Object {

        private unowned Gtk.Widget widget;

        double value;

        double value_from;
        double value_to;
        int64 duration;

        int64 start_time;
        uint tick_cb_id;
        ulong unmap_cb_id;

        unowned AnimationEasingFunc easing_func;
        unowned AnimationValueCallback value_cb;
        unowned AnimationDoneCallback done_cb;

        bool is_done;


        public delegate void AnimationValueCallback (double value);

        public delegate void AnimationDoneCallback ();

        public delegate double AnimationEasingFunc (double t);

        public Animation (Gtk.Widget widget, int64 duration,
                          AnimationEasingFunc easing_func,
                          AnimationValueCallback value_cb,
                          AnimationDoneCallback done_cb) {
            this.widget = widget;
            this.duration = duration;
            this.easing_func = easing_func;
            this.value_cb = value_cb;
            this.done_cb = done_cb;

            this.is_done = false;
        }

        ~Animation () {
            stop ();
        }

        void set_value (double value) {
            this.value = value;
            this.value_cb (value);
        }

        void done () {
            if (is_done) return;

            is_done = true;
            done_cb ();
        }

        bool tick_cb (Gtk.Widget widget, Gdk.FrameClock frame_clock) {
            int64 frame_time = frame_clock.get_frame_time () / 1000; /* ms */
            double t = (double) (frame_time - start_time) / duration;

            if (t >= 1) {
                tick_cb_id = 0;

                set_value (value_to);

                if (unmap_cb_id != 0) {
                    SignalHandler.disconnect (widget, unmap_cb_id);
                    unmap_cb_id = 0;
                }

                done ();

                return Source.REMOVE;
            }

            set_value (lerp (value_from, value_to, easing_func (t)));

            return Source.CONTINUE;
        }

        public void start (double from, double to) {
            this.value_from = from;
            this.value_to = to;
            this.value = from;
            this.is_done = false;

            unowned Gtk.Settings ? gsettings = Gtk.Settings.get_default ();
            bool animations_enabled =
                gsettings != null ? gsettings.gtk_enable_animations : true;
            if (animations_enabled != true ||
                !widget.get_mapped () || duration <= 0) {
                set_value (value_to);

                done ();
                return;
            }


            start_time = widget.get_frame_clock ().get_frame_time () / 1000;

            if (tick_cb_id != 0) return;

            unmap_cb_id =
                Signal.connect_swapped (widget, "unmap", (Callback) stop, this);
            tick_cb_id = widget.add_tick_callback (tick_cb);
        }

        public void stop () {
            if (tick_cb_id != 0) {
                widget.remove_tick_callback (tick_cb_id);
                tick_cb_id = 0;
            }

            if (unmap_cb_id != 0) {
                SignalHandler.disconnect (widget, unmap_cb_id);
                unmap_cb_id = 0;
            }

            done ();
        }

        public double get_value () {
            return value;
        }

        public static double lerp (double a, double b, double t) {
            return a * (1.0 - t) + b * t;
        }

        public static double ease_out_cubic (double t) {
            double p = t - 1;
            return p * p * p + 1;
        }

        public static double ease_in_cubic (double t) {
            return t * t * t;
        }

        public static double ease_in_out_cubic (double t) {
            double p = t * 2;

            if (p < 1) return 0.5 * p * p * p;

            p -= 2;

            return 0.5 * (p * p * p + 2);
        }
    }
}
