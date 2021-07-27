[DBus (name = "org.erikreider.swaync.cc")]
interface CcDaemon : GLib.Object {
    public abstract void toggle () throws DBusError, IOError;
}

public void main (string[] args) {
    try {
        CcDaemon controlCenter = Bus.get_proxy_sync (BusType.SESSION, "org.erikreider.swaync.cc",
                                                     "/org/erikreider/swaync/cc");
        controlCenter.toggle ();
    } catch (IOError e) {
        stderr.printf ("Could not connect to CC service\n");
    } catch (DBusError e) {
        stderr.printf ("Could not connect to CC service\n");
    }
}
