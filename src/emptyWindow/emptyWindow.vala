namespace SwayNotificationCenter {
    public class EmptyWindow : BlankWindow {
        public unowned Gdk.Monitor monitor { get; private set; }

        // TODO: Fix fully transparent windows not being shown...
        public EmptyWindow (Gdk.Monitor mon, SwayncDaemon swaync_daemon) {
            base (swaync_daemon);
            monitor = mon;
        }

        public override void set_custom_options () {
            GtkLayerShell.set_monitor (this, monitor);
        }

        public override Graphene.Rect? ignore_bounds () {
            return null;
        }
    }
}
