public struct SwayncDaemonData {
    public bool dnd;
    public bool cc_open;
    public uint count;
    public bool inhibited;
}

[DBus (name = "org.erikreider.swaync.cc")]
interface CcDaemon : Object {

    public abstract bool reload_css () throws Error;

    public abstract void reload_config () throws Error;

    public abstract void hide_latest_notifications (bool close) throws DBusError, IOError;

    public abstract void hide_all_notifications () throws DBusError, IOError;

    public abstract void close_all_notifications () throws DBusError, IOError;

    public abstract uint notification_count () throws DBusError, IOError;

    public abstract bool get_dnd () throws DBusError, IOError;

    public abstract void set_dnd (bool state) throws DBusError, IOError;

    public abstract bool get_visibility () throws DBusError, IOError;

    public abstract void toggle_visibility () throws DBusError, IOError;

    public abstract bool toggle_dnd () throws DBusError, IOError;

    public abstract void set_visibility (bool value) throws DBusError, IOError;

    public abstract void latest_invoke_action (uint32 action_index) throws DBusError, IOError;

    public abstract bool set_cc_monitor (string monitor) throws DBusError, IOError;
    public abstract bool set_noti_window_monitor (string monitor) throws DBusError, IOError;

    [DBus (name = "GetSubscribeData")]
    public abstract SwayncDaemonData get_subscribe_data () throws Error;

    public signal void subscribe_v2 (uint count, bool dnd, bool cc_open, bool inhibited);

    public abstract bool add_inhibitor (string application_id) throws DBusError, IOError;
    public abstract bool remove_inhibitor (string application_id) throws DBusError, IOError;
    public abstract uint number_of_inhibitors () throws DBusError, IOError;
    public abstract bool is_inhibited () throws DBusError, IOError;
    public abstract bool clear_inhibitors () throws DBusError, IOError;
}

private CcDaemon cc_daemon = null;

private void print_help (string[] args) {
    print ("Usage:\n");
    print ("  %s <OPTION>\n".printf (args[0]));
    print ("Help:\n");
    print ("  -h, \t --help \t\t\t Show help options\n");
    print ("  -v, \t --version \t\t\t Prints version\n");
    print ("Options:\n");
    print ("  -R, \t --reload-config \t\t Reload the config file\n");
    print ("  -rs, \t --reload-css \t\t\t Reload the css file. Location change requires restart\n");
    print ("  -t, \t --toggle-panel \t\t Toggle the notification panel\n");
    print ("  -op, \t --open-panel \t\t\t Opens the notification panel\n");
    print ("  -cp, \t --close-panel \t\t\t Closes the notification panel\n");
    print ("  -d, \t --toggle-dnd \t\t\t Toggle and print the current dnd state\n");
    print ("  -D, \t --get-dnd \t\t\t Print the current dnd state\n");
    print ("  -dn, \t --dnd-on \t\t\t Turn dnd on and print the new dnd state\n");
    print ("  -df, \t --dnd-off \t\t\t Turn dnd off and print the new dnd state\n");
    print ("  -I, \t --get-inhibited \t\t Print if currently inhibited or not\n");
    print ("  -In, \t --get-num-inhibitors \t\t Print number of inhibitors\n");
    print ("  -Ia, \t --inhibitor-add [APP_ID] \t Add an inhibitor\n");
    print ("  -Ir, \t --inhibitor-remove [APP_ID] \t Remove an inhibitor\n");
    print ("  -Ic, \t --inhibitors-clear \t\t Clears all inhibitors\n");
    print ("  -c, \t --count \t\t\t Print the current notification count\n");
    print ("      \t --hide-latest \t\t\t Hides latest notification. Still shown in Control Center\n");
    print ("      \t --hide-all \t\t\t Hides all notifications. Still shown in Control Center\n");
    print ("      \t --close-latest \t\t Closes latest notification\n");
    print ("  -C, \t --close-all \t\t\t Closes all notifications\n");
    print ("  -a, \t --action [ACTION_INDEX]\t Invokes the action [ACTION_INDEX] of the latest notification\n");
    print ("  -sw, \t --skip-wait \t\t\t Doesn't wait when swaync hasn't been started\n");
    print ("  -s, \t --subscribe \t\t\t Subscribe to notification add and close events\n");
    print ("  -swb,  --subscribe-waybar \t\t Subscribe to notification add and close events "
           + "with waybar support. Read README for example\n");
    print ("      \t --change-cc-monitor \t\t Changes the preferred control center monitor"
           + " (resets on config reload)\n");
    print ("      \t --change-noti-monitor \t\t Changes the preferred notification monitor"
           + " (resets on config reload)\n");
}

private void on_subscribe (uint count, bool dnd, bool cc_open, bool inhibited) {
    stdout.printf (
        "{ \"count\": %u, \"dnd\": %s, \"visible\": %s, \"inhibited\": %s }\n",
         count, dnd.to_string (), cc_open.to_string (), inhibited.to_string ());
    stdout.flush ();
}

private void print_subscribe () {
    try {
        SwayncDaemonData data = cc_daemon.get_subscribe_data ();
        on_subscribe (data.count, data.dnd, data.cc_open, data.inhibited);
    } catch (Error e) {
        on_subscribe (0, false, false, false);
    }
}

private void on_subscribe_waybar (uint count, bool dnd, bool cc_open, bool inhibited) {
    string state = (dnd ? "dnd-" : "")
                   + (inhibited ? "inhibited-" : "")
                   + (count > 0 ? "notification" : "none");

    string tooltip = "";
    if (count > 0) {
        tooltip = "%u Notification%s".printf (count, count > 1 ? "s" : "");
    }

    string _class = "\"%s\"".printf (state);
    if (cc_open) {
        _class = "[%s, \"cc-open\"]".printf (_class);
    }

    print (
        "{\"text\": \"%u\", \"alt\": \"%s\", \"tooltip\": \"%s\", \"class\": %s}\n",
        count, state, tooltip, _class);
}

private void print_subscribe_waybar () {
    try {
        SwayncDaemonData data = cc_daemon.get_subscribe_data ();
        on_subscribe_waybar (data.count, data.dnd, data.cc_open, data.inhibited);
    } catch (Error e) {
        on_subscribe_waybar (0, false, false, false);
    }
}

public int command_line (ref string[] args, bool skip_wait) {
    // Used to know how many args the current command consumed
    int used_args = 1;
    try {
        if (args.length < 1) {
            print_help (args);
            Process.exit (1);
        }
        switch (args[0]) {
            case "--help":
            case "-h":
                print_help (args);
                break;
            case "--version":
            case "-v":
                stdout.printf ("%s\n", Constants.VERSION);
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
            case "--close-latest":
                cc_daemon.hide_latest_notifications (true);
                break;
            case "--hide-latest":
                cc_daemon.hide_latest_notifications (false);
                break;
            case "--hide-all":
                cc_daemon.hide_all_notifications ();
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
            case "--dnd-on":
            case "-dn":
                cc_daemon.set_dnd (true);
                print (cc_daemon.get_dnd ().to_string ());
                break;
            case "--dnd-off":
            case "-df":
                cc_daemon.set_dnd (false);
                print (cc_daemon.get_dnd ().to_string ());
                break;
            case "--action":
            case "-a":
                int action_index = 0;
                if (args.length >= 2) {
                    used_args++;
                    action_index = int.parse (args[1]);
                }
                cc_daemon.latest_invoke_action ((uint32) action_index);
                break;
            case "--get-inhibited":
            case "-I":
                print (cc_daemon.is_inhibited ().to_string ());
                break;
            case "--get-num-inhibitors":
            case "-In":
                print (cc_daemon.number_of_inhibitors ().to_string ());
                break;
            case "--inhibitor-add":
            case "-Ia":
                if (args.length < 2) {
                    stderr.printf ("Application ID needed!");
                    Process.exit (1);
                }
                used_args++;
                if (cc_daemon.add_inhibitor (args[1])) {
                    print ("Added inhibitor: \"%s\"", args[1]);
                    break;
                }
                stderr.printf ("Inhibitor: \"%s\" already added!...", args[1]);
                break;
            case "--inhibitor-remove":
            case "-Ir":
                if (args.length < 2) {
                    stderr.printf ("Application ID needed!");
                    Process.exit (1);
                }
                used_args++;
                if (cc_daemon.remove_inhibitor (args[1])) {
                    print ("Removed inhibitor: \"%s\"", args[1]);
                    break;
                }
                stderr.printf ("Inhibitor: \"%s\" does not exist!...", args[1]);
                break;
            case "inhibitors-clear":
            case "-Ic":
                if (cc_daemon.clear_inhibitors ()) {
                    print ("Cleared all inhibitors");
                    break;
                }
                print ("No inhibitors to clear...");
                break;
            case "--subscribe":
            case "-s":
                cc_daemon.subscribe_v2.connect (on_subscribe);
                var data = cc_daemon.get_subscribe_data ();
                on_subscribe (data.count,
                              data.dnd,
                              data.cc_open,
                              data.inhibited);
                var loop = new MainLoop ();
                Bus.watch_name (
                    BusType.SESSION,
                    "org.erikreider.swaync.cc",
                    BusNameWatcherFlags.NONE,
                    print_subscribe,
                    print_subscribe);
                loop.run ();
                break;
            case "--subscribe-waybar":
            case "-swb":
                cc_daemon.subscribe_v2.connect (on_subscribe_waybar);
                var loop = new MainLoop ();
                Bus.watch_name (
                    BusType.SESSION,
                    "org.erikreider.swaync.cc",
                    BusNameWatcherFlags.NONE,
                    print_subscribe_waybar,
                    print_subscribe_waybar);
                loop.run ();
                break;
            case "--change-cc-monitor":
                if (args.length < 2) {
                    stderr.printf ("Monitor connector name needed!");
                    Process.exit (1);
                }
                used_args++;
                if (cc_daemon.set_cc_monitor (args[1])) {
                    print ("Changed monitor to: \"%s\"", args[1]);
                    break;
                }
                stderr.printf ("Could not find monitor: \"%s\"!", args[1]);
                break;
            case "--change-noti-monitor":
                if (args.length < 2) {
                    stderr.printf ("Monitor connector name needed!");
                    Process.exit (1);
                }
                used_args++;
                if (cc_daemon.set_noti_window_monitor (args[1])) {
                    print ("Changed monitor to: \"%s\"", args[1]);
                    break;
                }
                stderr.printf ("Could not find monitor: \"%s\"!", args[1]);
                break;
            default:
                print ("Unknown command: \"%s\"\n", args[0]);
                print_help (args);
                break;
        }
    } catch (Error e) {
        stderr.printf (e.message + "\n");
        if (skip_wait) Process.exit (1);
        return 1;
    }

    args = args[used_args:];
    return 0;
}

void print_connection_error () {
    stderr.printf (
        "Could not connect to CC service. Will wait for connection...\n");
}

int try_connect (owned string[] args) {
    try {
        cc_daemon = Bus.get_proxy_sync (
            BusType.SESSION,
            "org.erikreider.swaync.cc",
            "/org/erikreider/swaync/cc");

        bool skip_wait = "--skip-wait" in args || "-sw" in args;
        bool one_arg = true;
        while (args.length > 0) {
            if (args[0] == "--skip-wait" || args[0] == "-sw") {
                args = args[1:];
                continue;
            }
            if (!one_arg) {
                // Separate each command output
                print ("\n");
            }
            if (command_line (ref args, skip_wait) == 1) {
                print_connection_error ();
                return 1;
            }
            one_arg = false;
        }
        // Should only be reached if the args only contains --skip-wait or -sw
        if (one_arg) {
            stderr.printf ("Skipping wait, but with no action.");
        }
        return 0;
    } catch (Error e) {
        print_connection_error ();
        return 1;
    }
}

public int main (string[] args) {
    if (try_connect (args[1:]) == 1) {
        MainLoop loop = new MainLoop ();
        Bus.watch_name (
            BusType.SESSION,
            "org.erikreider.swaync.cc",
            BusNameWatcherFlags.NONE,
            (conn, name, name_owner) => {
            if (try_connect (args[1:]) == 0) loop.quit ();
        },
            null);
        loop.run ();
    }
    return 0;
}
