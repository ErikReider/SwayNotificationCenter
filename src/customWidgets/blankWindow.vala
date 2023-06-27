namespace SwayNotificationCenter {
    public abstract class BlankWindow : Gtk.Window {
        public unowned SwayncDaemon swaync_daemon;

        private Gtk.GestureClick gesture_click;
        private bool blank_window_down = false;
        private bool blank_window_in = false;

        protected BlankWindow (SwayncDaemon swaync_daemon) {
            this.swaync_daemon = swaync_daemon;

            add_css_class ("blank-window");
            set_decorated (false);

            if (swaync_daemon.use_layer_shell) {
                if (!GtkLayerShell.is_supported ()) {
                    stderr.printf ("GTKLAYERSHELL IS NOT SUPPORTED!\n");
                    stderr.printf ("Swaync only works on Wayland!\n");
                    stderr.printf ("If running wayland session, try running:\n");
                    stderr.printf ("\tGDK_BACKEND=wayland swaync\n");
                    Process.exit (1);
                }
                GtkLayerShell.init_for_window (this);
                GtkLayerShell.set_namespace (this, "swaync-control-center");
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);
                GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);

                set_layer_options ();
            }

            ((Gtk.Widget) this).realize.connect (() => {
                set_layer_options ();
            });

            /*
             * Handling of bank window presses (pressing outside of ControlCenter)
             */
            ((Gtk.Widget) this).add_controller (gesture_click = new Gtk.GestureClick () {
                touch_only = false,
                exclusive = true,
                button = Gdk.BUTTON_PRIMARY,
                propagation_phase = Gtk.PropagationPhase.BUBBLE,
            });
            gesture_click.pressed.connect ((n_press, x, y) => {
                // Calculate if the clicked coords intersect the ControlCenter
                Graphene.Point click_point = Graphene.Point ()
                    .init ((float) x, (float) y);
                Graphene.Rect ? bounds = ignore_bounds ();
                blank_window_in = !(bounds != null && bounds.contains_point (click_point));
                blank_window_down = true;
            });
            gesture_click.released.connect ((n_press, x, y) => {
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

                if (gesture_click.get_current_sequence () == null) {
                    blank_window_in = false;
                }
            });
            gesture_click.update.connect ((gesture, sequence) => {
                Gtk.GestureSingle gesture_single = (Gtk.GestureSingle) gesture;
                if (sequence != gesture_single.get_current_sequence ()) return;
                // Calculate if the clicked coords intersect the ControlCenter
                double x, y;
                gesture.get_point (sequence, out x, out y);
                Graphene.Point click_point = Graphene.Point ()
                    .init ((float) x, (float) y);
                Graphene.Rect ? bounds = ignore_bounds ();
                if (bounds != null && bounds.contains_point (click_point)) {
                    blank_window_in = false;
                }
            });
            gesture_click.cancel.connect (() => {
                blank_window_down = false;
            });
        }

        public abstract Graphene.Rect ? ignore_bounds ();

        /** Called by `set_layer_options` */
        public abstract void set_custom_options ();

        protected void set_layer_options () {
            if (swaync_daemon.use_layer_shell) {
                GtkLayerShell.Layer layer;
                switch (ConfigModel.instance.control_center_layer) {
                    case Layer.BACKGROUND:
                        layer = GtkLayerShell.Layer.BACKGROUND;
                        break;
                    case Layer.BOTTOM:
                        layer = GtkLayerShell.Layer.BOTTOM;
                        break;
                    case Layer.TOP:
                        layer = GtkLayerShell.Layer.TOP;
                        break;
                    default:
                    case Layer.OVERLAY:
                        layer = GtkLayerShell.Layer.OVERLAY;
                        break;
                }
                GtkLayerShell.set_layer (this, layer);
            }

            set_custom_options ();
        }
    }
}
