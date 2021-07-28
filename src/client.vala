[DBus (name = "org.erikreider.swaync.cc")]
interface CcDaemon : GLib.Object {

    public abstract uint notification_count () throws DBusError, IOError;

    public abstract void toggle () throws DBusError, IOError;

    public signal void on_notificaion (uint count);
}


public class Client : Application {
    private CcDaemon cc_daemon = null;

    public Client () {
        Object (application_id: "org.erikreider.swaync.client",
                flags : ApplicationFlags.HANDLES_COMMAND_LINE);
        set_inactivity_timeout (10000);
        try {
            cc_daemon = Bus.get_proxy_sync (
                BusType.SESSION,
                "org.erikreider.swaync.cc",
                "/org/erikreider/swaync/cc");
        } catch (Error e) {
            stderr.printf ("Could not connect to CC service\n");
        }
    }

    private void print_help (string[] args) {
        print(@"Usage:\n");
        print(@"\t $(args[0]) <OPTION>\n");
        print(@"Help:\n");
        print(@"\t -h, --help \t\t Show help options\n");
        print(@"Options:\n");
        print(@"\t -t, --toggle \t\t Toggle the notificaion panel\n");
        print(@"\t -c, --count \t\t Print the current notificaion count\n");
        print(@"\t -s, --subscribe \t Subscribe to notificaion add and close events\n");
    }

    public override int command_line (ApplicationCommandLine cmd_line) {
        try {
            string[] args = cmd_line.get_arguments ();
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
                case "--toggle":
                case "-t":
                    cc_daemon.toggle ();
                    break;
                case "--subscribe":
                case "-s":
                    cc_daemon.on_notificaion.connect ((c) => print (c.to_string ()));
                    var loop = new MainLoop ();
                    loop.run ();
                    break;
            }
        } catch (Error e) {
            stderr.printf (e.message + "\n");
            return 1;
        }
        return 0;
    }

    public static int main (string[] args) {
        Client client = new Client ();
        int status = client.run (args);
        return status;
    }
}
