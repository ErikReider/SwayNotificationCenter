[DBus (name = "org.erikreider.swaync.cc")]
interface CcDaemon : GLib.Object {

    public abstract uint notification_count () throws DBusError, IOError;

    public abstract void toggle () throws DBusError, IOError;

    public abstract uint toggle_dnd () throws DBusError, IOError;

    public signal void subscribe (uint count, bool dnd);
}

private CcDaemon cc_daemon = null;

private void print_help (string[] args) {
    print (@"Usage:\n");
    print (@"\t $(args[0]) <OPTION>\n");
    print (@"Help:\n");
    print (@"\t -h, --help \t\t Show help options\n");
    print (@"Options:\n");
    print (@"\t -t, --toggle-panel \t\t Toggle the notificaion panel\n");
    print (@"\t -c, --count \t\t Print the current notificaion count\n");
    print (@"\t -d, --toggle-dnd \t\t Toggle and print the current dnd state\n");
    print (@"\t -s, --subscribe \t Subscribe to notificaion add and close events\n");
}

private void on_subscribe (uint count, bool dnd) {
    stdout.write (@"{ \"count\": $(count), \"dnd\": $(dnd) }".data);
    print ("\n");
}

public int command_line (string[] args) {
    if (cc_daemon == null) return 1;
    try {
        if (args.length < 2) {
            print_help (args);
            return 1;
        }
        switch (args[1]) {
            case "--help":
            case "-h":
                print_help (args);
                break;
            case "--count":
            case "-c":
                print (cc_daemon.notification_count ().to_string ());
                break;
            case "--toggle-panel":
            case "-t":
                cc_daemon.toggle ();
                break;
            case "--toggle-dnd":
            case "-d":
                print (cc_daemon.toggle_dnd ().to_string ());
                break;
            case "--subscribe":
            case "-s":
                cc_daemon.subscribe.connect ((c, d) => on_subscribe (c, d));
                var loop = new MainLoop ();
                loop.run ();
                break;
            default:
                print_help (args);
                break;
        }
    } catch (Error e) {
        stderr.printf (e.message + "\n");
        return 1;
    }
    return 0;
}

public int main (string[] args) {
    try {
        cc_daemon = Bus.get_proxy_sync (
            BusType.SESSION,
            "org.erikreider.swaync.cc",
            "/org/erikreider/swaync/cc");
        return command_line (args);
    } catch (Error e) {
        stderr.printf ("Could not connect to CC service\n");
        return 1;
    }
}
