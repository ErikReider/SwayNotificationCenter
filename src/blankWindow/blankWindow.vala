namespace SwayNotificationCenter {
    public class BlankWindow : Gtk.ApplicationWindow {
        public unowned Gdk.Monitor monitor { get; private set; }

        private Gtk.GestureClick blank_window_gesture;
        private bool blank_window_down = false;
        private bool blank_window_in = false;

        public BlankWindow (Gdk.Monitor monitor) {
            Object (css_name: "blankwindow");
            this.monitor = monitor;

            blank_window_gesture = new Gtk.GestureClick ();
            ((Gtk.Widget) this).add_controller (blank_window_gesture);
            blank_window_gesture.touch_only = false;
            blank_window_gesture.exclusive = true;
            blank_window_gesture.button = Gdk.BUTTON_PRIMARY;
            blank_window_gesture.propagation_phase = Gtk.PropagationPhase.BUBBLE;
            blank_window_gesture.pressed.connect ((n_press, x, y) => {
                blank_window_in = true;
                blank_window_down = true;
            });
            blank_window_gesture.released.connect ((n_press, x, y) => {
                // Emit released
                if (!blank_window_down) return;
                blank_window_down = false;
                if (blank_window_in) {
                    try {
                        swaync_daemon.set_visibility (false);
                    } catch (Error e) {
                        stderr.printf ("ControlCenter BlankWindow Click Error: %s\n",
                                       e.message);
                    }
                }

                if (blank_window_gesture.get_current_sequence () == null) {
                    blank_window_in = false;
                }
            });
            blank_window_gesture.update.connect ((gesture, sequence) => {
                Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
                if (sequence != gesture_single.get_current_sequence ()) return;
                // Calculate if the clicked coords intersect other monitors
                double x, y;
                gesture.get_point (sequence, out x, out y);
                Graphene.Point click_point = Graphene.Point ()
                    .init ((float) x, (float) y);
                Graphene.Rect ? bounds = null;
                this.compute_bounds (this, out bounds);
                if (bounds != null && bounds.contains_point (click_point)) {
                    blank_window_in = false;
                }
            });
            blank_window_gesture.cancel.connect (() => {
                blank_window_down = false;
            });

            if (!GtkLayerShell.is_supported ()) {
                stderr.printf ("GTKLAYERSHELL IS NOT SUPPORTED!\n");
                stderr.printf ("Swaync only works on Wayland!\n");
                stderr.printf ("If running waylans session, try running:\n");
                stderr.printf ("\tGDK_BACKEND=wayland swaync\n");
                Process.exit (1);
            }
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_namespace (this, "swaync-control-center");
            GtkLayerShell.set_monitor (this, monitor);

            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);

            GtkLayerShell.set_exclusive_zone (this, -1);

            GtkLayerShell.set_layer (
                this, ConfigModel.instance.control_center_layer.to_layer ());

            add_css_class ("blank-window");
        }

        protected override void snapshot (Gtk.Snapshot snapshot) {
            // HACK: Fixes fully transparent windows not being mapped
            Gdk.RGBA color = Gdk.RGBA () {
                red = 0,
                green = 0,
                blue = 0,
                alpha = 0,
            };
            snapshot.append_color (color, Graphene.Rect.zero ());
            base.snapshot (snapshot);
        }
    }
}
