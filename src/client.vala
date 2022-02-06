[DBus (name = "org.erikreider.swaync.cc")]
interface CcDaemon : GLib.Object {

    public abstract bool reload_css () throws Error;

    public abstract void reload_config () throws Error;

    public abstract void close_all_notifications () throws DBusError, IOError;

    public abstract uint notification_count () throws DBusError, IOError;

    public abstract bool get_dnd () throws DBusError, IOError;

    public abstract void toggle_visibility () throws DBusError, IOError;

    public abstract bool toggle_dnd () throws DBusError, IOError;

    public abstract void set_visibility (bool value) throws DBusError, IOError;

    public signal void subscribe (uint count, bool dnd);
}

private CcDaemon cc_daemon = null;

private void print_help (string[] args) {
    print (@"Usage:\n");
    print (@"\t $(args[0]) <OPTION>\n");
    print (@"Help:\n");
    print (@"\t -h, \t --help \t\t Show help options\n");
    print (@"\t -v, \t --version \t\t Prints version\n");
    print (@"Options:\n");
    print (@"\t -R, \t --reload-config \t Reload the config file\n");
    print (@"\t -rs, \t --reload-css \t\t Reload the css file. Location change requires restart\n");
    print (@"\t -t, \t --toggle-panel \t Toggle the notificaion panel\n");
    print (@"\t -op, \t --open-panel \t\t Opens the notificaion panel\n");
    print (@"\t -cp, \t --close-panel \t\t Closes the notificaion panel\n");
    print (@"\t -d, \t --toggle-dnd \t\t Toggle and print the current dnd state\n");
    print (@"\t -D, \t --get-dnd \t\t Print the current dnd state\n");
    print (@"\t -c, \t --count \t\t Print the current notificaion count\n");
    print (@"\t -C, \t --close-all \t\t Closes all notifications\n");
    print (@"\t -sw, \t --skip-wait \t\t Doesn't wait when swaync hasn't been started\n");
    print (@"\t -s, \t --subscribe \t\t Subscribe to notificaion add and close events\n");
    print (@"\t -swb, \t --subscribe-waybar \t Subscribe to notificaion add and close events with waybar support. Read README for example\n");
}

private void on_subscribe (uint count, bool dnd) {
    stdout.write (@"{ \"count\": $(count), \"dnd\": $(dnd) }".data);
    print ("\n");
}

private void on_subscribe_waybar (uint count, bool dnd) {
    string state = (dnd ? "dnd-" : "") + (count > 0 ? "notification" : "none");
    print ("{\"text\": \"\", \"alt\": \"%s\", \"tooltip\": \"\", \"class\": \"%s\"}\n",
           state, state);
}

public int command_line (string[] args) {
    bool skip_wait = "--skip-wait" in args || "-sw" in args;

    try {
        if (args.length < 2) {
            print_help (args);
            Process.exit (1);
        }
        switch (args[1]) {
            case "--help":
            case "-h":
                print_help (args);
                break;
            case "--version":
            case "-v":
                stdout.printf ("%s\n", Constants.version);
                break;
            case "--reload-config":
            case "-R":
                cc_daemon.reload_config ();
                break;
            case "--reload-css":
            case "-rs":
                stdout.printf ("CSS reload success: %s\n",
                               cc_daemon.reload_css ().to_string ());
                break;
            case "--count":
            case "-c":
                print (cc_daemon.notification_count ().to_string ());
                break;
            case "--close-all":
            case "-C":
                cc_daemon.close_all_notifications ();
                break;
            case "--toggle-panel":
            case "-t":
                cc_daemon.toggle_visibility ();
                break;
            case "--open-panel":
            case "-op":
                cc_daemon.set_visibility (true);
                break;
            case "--close-panel":
            case "-cp":
                cc_daemon.set_visibility (false);
                break;
            case "--toggle-dnd":
            case "-d":
                print (cc_daemon.toggle_dnd ().to_string ());
                break;
            case "--get-dnd":
            case "-D":
                print (cc_daemon.get_dnd ().to_string ());
                break;
            case "--subscribe":
            case "-s":
                cc_daemon.subscribe.connect (on_subscribe);
                on_subscribe (cc_daemon.notification_count (),
                              cc_daemon.get_dnd ());
                var loop = new MainLoop ();
                loop.run ();
                break;
            case "--subscribe-waybar":
            case "-swb":
                cc_daemon.subscribe.connect (on_subscribe_waybar);
                on_subscribe_waybar (cc_daemon.notification_count (),
                                     cc_daemon.get_dnd ());
                var loop = new MainLoop ();
                loop.run ();
                break;
            default:
                print_help (args);
                break;
        }
    } catch (Error e) {
        stderr.printf (e.message + "\n");
        if (skip_wait) Process.exit (1);
        return 1;
    }
    return 0;
}

void print_connection_error () {
    stderr.printf (
        "Could not connect to CC service. Will wait for connection...\n");
}

int try_connect (string[] args) {
    try {
        cc_daemon = Bus.get_proxy_sync (
            BusType.SESSION,
            "org.erikreider.swaync.cc",
            "/org/erikreider/swaync/cc");
        if (command_line (args) == 1) {
            print_connection_error ();
            return 1;
        }
        return 0;
    } catch (Error e) {
        print_connection_error ();
        return 1;
    }
}

public int main (string[] args) {
    if (try_connect (args) == 1) {
        MainLoop loop = new MainLoop ();
        Bus.watch_name (
            BusType.SESSION,
            "org.erikreider.swaync.cc",
            GLib.BusNameWatcherFlags.NONE,
            (conn, name, name_owner) => {
            if (try_connect (args) == 0) loop.quit ();
        },
            null);
        loop.run ();
    }
    return 0;
}
