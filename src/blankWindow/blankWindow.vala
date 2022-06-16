namespace SwayNotificationCenter {
    public class BlankWindow : Gtk.Window {
        unowned Gdk.Display display;
        unowned Gdk.Monitor monitor;
        unowned SwayncDaemon daemon;

        Gtk.Button button;

        public BlankWindow (Gdk.Display disp,
                            Gdk.Monitor mon,
                            SwayncDaemon dae) {
            display = disp;
            monitor = mon;
            daemon = dae;

            // Use button click event instead of Window button_press_event due
            // to Gtk layer shell bug. This would grab focus instead of ControlCenter
            button = new Gtk.Button () {
                expand = true,
                opacity = 0,
                relief = Gtk.ReliefStyle.NONE,
                visible = true,
            };
            button.clicked.connect (() => {
                try {
                    daemon.set_visibility (false);
                } catch (Error e) {
                    stderr.printf ("BlankWindow Click Error: %s\n", e.message);
                }
            });
            add (button);

            if (!GtkLayerShell.is_supported ()) {
                stderr.printf ("GTKLAYERSHELL IS NOT SUPPORTED!\n");
                stderr.printf ("Swaync only works on Wayland!\n");
                stderr.printf ("If running waylans session, try running:\n");
                stderr.printf ("\tGDK_BACKEND=wayland swaync\n");
                Process.exit (1);
            }
            GtkLayerShell.init_for_window (this);
            GtkLayerShell.set_monitor (this, monitor);

            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.TOP, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.BOTTOM, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.LEFT, true);
            GtkLayerShell.set_anchor (this, GtkLayerShell.Edge.RIGHT, true);

            GtkLayerShell.set_exclusive_zone (this, -1);

            GtkLayerShell.set_layer (this, GtkLayerShell.Layer.TOP);

            get_style_context ().add_class ("blank-window");
        }
    }
}
