namespace SwayNotificationCenter {
    static NotiDaemon noti_daemon;
    static SwayncDaemon swaync_daemon;
    static Widgets.Notifications notifications_widget;
    static ControlCenter control_center;

    static unowned ListModel ?monitors = null;
    static Swaync app;
    static Settings self_settings;

    static HashTable<string, unowned Gdk.PixbufFormat> pixbuf_mime_types;

    // Args
    static string ?style_path;
    static string ?config_path;
    // Dev args
    static bool skip_packaged_css = false;
    static string ?custom_packaged_css;

    private struct EnvironmentVariable {
        string name;

        public EnvironmentVariable (string name) {
            this.name = name;
        }

        public string to_string (string[] envp) {
            return "%s=%s".printf (name, Environ.get_variable (envp, name) ?? "");
        }
    }

    public class Swaync : Gtk.Application {
        private bool activated = false;
        private Array<BlankWindow> blank_windows = new Array<BlankWindow> ();

        // Only set on swaync start due to some limitations of GtkLayerShell
        public bool use_layer_shell = true;
        public bool has_layer_on_demand = true;

        public XdgActivationHelper xdg_activation;

        public signal void config_reload (ConfigModel ?old_config, ConfigModel new_config);

        public Swaync () {
            Object (
                application_id : "org.erikreider.swaync",
                flags: ApplicationFlags.DEFAULT_FLAGS
            );

            try {
                register ();
                if (get_is_remote ()) {
                    printerr ("An instance of SwayNotificationCenter is already running!\n");
                    Process.exit (1);
                }
            } catch (Error e) {
                error (e.message);
            }
        }

        public override void activate () {
            if (activated) {
                return;
            }
            activated = true;
            init.begin ();
        }

        private async void init () {
            Functions.load_css (style_path);

            pixbuf_mime_types =
                new HashTable<string, unowned Gdk.PixbufFormat> (str_hash, str_equal);
            SList<weak Gdk.PixbufFormat> formats = Gdk.Pixbuf.get_formats ();
            foreach (weak Gdk.PixbufFormat format in formats) {
                foreach (string mime_type in format.get_mime_types ()) {
                    pixbuf_mime_types.set (mime_type, format);
                }
            }

            hold ();

            unowned Gdk.Display ?display = Gdk.Display.get_default ();
            if (display == null) {
                error ("Could not get Display!");
            }
            monitors = display.get_monitors ();
            assert_nonnull (monitors);
            print_monitors ();

            use_layer_shell = ConfigModel.instance.layer_shell;
            has_layer_on_demand = use_layer_shell &&
                GtkLayerShell.get_protocol_version () >= 4;

            DBusConnection conn;
            try {
                conn = Bus.get_sync (GLib.BusType.SESSION, null);
            } catch (Error e) {
                error ("Could not connect to DBus!... (%s)\n", e.message);
            }

            noti_daemon = new NotiDaemon ();
            swaync_daemon = new SwayncDaemon ();
            // Notification Daemon
            Bus.own_name_on_connection (conn,
                                        "org.freedesktop.Notifications",
                                        BusNameOwnerFlags.NONE,
                                        () => {
                try {
                    conn.register_object ("/org/freedesktop/Notifications", noti_daemon);
                    init.callback ();
                } catch (Error e) {
                    error ("Could not register notification service: \"%s\"", e.message);
                }
            },
                                        () => {
                stderr.printf (
                    "Could not acquire notification name. " +
                    "Please close any other notification daemon " +
                    "like mako or dunst\n");
                Process.exit (1);
            });
            yield;

            // Swaync Daemon
            Bus.own_name_on_connection (conn,
                                        "org.erikreider.swaync.cc",
                                        BusNameOwnerFlags.NONE,
                                        () => {
                try {
                    conn.register_object ("/org/erikreider/swaync/cc", swaync_daemon);
                    init.callback ();
                } catch (Error e) {
                    error ("Could not register CC service: \"%s\"", e.message);
                }
            },
                                        () => {
                error ("Could not acquire swaync name!");
            });
            yield;

            xdg_activation = new XdgActivationHelper ();

            notifications_widget = new Widgets.Notifications ();
            control_center = new ControlCenter ();

            add_window (control_center);

            noti_daemon.on_dnd_toggle.connect ((dnd) => {
                // Hide all non-critical notifications on toggle
                if (dnd && !NotificationWindow.is_null) {
                    NotificationWindow.instance.hide_all_notifications ((noti) => {
                        return noti.param.urgency != UrgencyLevels.CRITICAL;
                    });
                }

                try {
                    swaync_daemon.subscribe_v2 (swaync_daemon.notification_count (),
                                  dnd,
                                  swaync_daemon.get_visibility (),
                                  swaync_daemon.inhibited);
                } catch (Error e) {
                    stderr.printf (e.message + "\n");
                }
            });
            // Update on start
            try {
                swaync_daemon.subscribe_v2 (swaync_daemon.notification_count (),
                              swaync_daemon.get_dnd (),
                              swaync_daemon.get_visibility (),
                              swaync_daemon.inhibited);
            } catch (Error e) {
                stderr.printf (e.message + "\n");
            }

            monitors.items_changed.connect (monitors_changed);
            Idle.add_once (() => monitors_changed (0, 0, monitors.get_n_items ()));
        }

        private void monitors_changed (uint position, uint removed, uint added) {
            info ("Monitors Changed:");
            print_monitors ();

            bool visible = control_center.get_visibility ();

            for (uint i = 0; i < removed; i++) {
                unowned BlankWindow win = blank_windows.index (position + i);
                win.close ();
                blank_windows.remove_index (position + i);
            }

            for (uint i = 0; i < added; i++) {
                Gdk.Monitor monitor = (Gdk.Monitor) monitors.get_item (position + i);
                BlankWindow win = new BlankWindow (monitor);
                win.set_visible (visible);
                blank_windows.insert_val (position + i, win);
            }

            // Set preferred output
            try {
                swaync_daemon.set_cc_monitor (
                    ConfigModel.instance.control_center_preferred_output);
                swaync_daemon.set_noti_window_monitor (
                    ConfigModel.instance.notification_window_preferred_output);
            } catch (Error e) {
                critical (e.message);
            }
        }

        public void show_blank_windows (Gdk.Monitor ?ref_monitor) {
            if (!use_layer_shell || !ConfigModel.instance.layer_shell_cover_screen) {
                return;
            }
            foreach (unowned BlankWindow win in blank_windows.data) {
                if (win.monitor != ref_monitor) {
                    win.show ();
                }
            }
        }

        public void hide_blank_windows () {
            if (!use_layer_shell) {
                return;
            }
            foreach (unowned BlankWindow win in blank_windows.data) {
                win.hide ();
            }
        }

        private void print_monitors () {
            uint num_monitors = monitors.get_n_items ();
            string monitors_string = "";
            for (uint i = 0; i < num_monitors; i++) {
                Gdk.Monitor ?mon = (Gdk.Monitor) monitors.get_item (i);
                if (mon == null) {
                    continue;
                }
                monitors_string += Functions.monitor_to_string (mon);
            }
            info ("Monitors:\n%s", monitors_string);
        }

        public static int main (string[] args) {
            if (args.length > 0) {
                for (uint i = 1; i < args.length; i++) {
                    string arg = args[i];
                    switch (arg) {
                        case "-s" :
                        case "--style" :
                            style_path = args[++i];
                            break;
                        case "--skip-system-css":
                            skip_packaged_css = true;
                            break;
                        case "--custom-system-css":
                            custom_packaged_css = args[++i];
                            break;
                        case "-c":
                        case "--config":
                            config_path = args[++i];
                            break;
                        case "-v":
                        case "--version":
                            stdout.printf ("%s\n", Constants.VERSION);
                            return 0;
                        case "-h":
                        case "--help":
                            print_help (args);
                            return 0;
                        default:
                            print_help (args);
                            return 1;
                    }
                }
            }

            print_startup_info ();

            // Register custom Widgets so that they can be used in .ui template files
            typeof (AnimatedList).ensure ();
            typeof (AnimatedListItem).ensure ();
            typeof (Underlay).ensure ();

            ConfigModel.init (config_path);

            // Fixes custom themes messing with the default/custom CSS styling
            if (ConfigModel.instance.ignore_gtk_theme) {
                Environment.unset_variable ("GTK_THEME");
            }

            Gtk.init ();
            Adw.init ();

            Functions.init ();
            self_settings = new Settings ("org.erikreider.swaync");

            app = new Swaync ();
            return app.run ();
        }

        private static void print_startup_info () {
            print ("Starting SwayNotificationCenter version %s\n", Constants.VERSION);

            // Log distro information
            string info_paths[5] = {
                "/etc/lsb-release",
                "/etc/os-release",
                "/etc/debian_version",
                "/etc/redhat-release",
                "/etc/gentoo-release",
            };
            foreach (unowned string path in info_paths) {
                File ?file = File.new_for_path (path);
                if (file == null) {
                    continue;
                }
                string lines = "";
                try {
                    FileInputStream file_stream = file.read (null);
                    DataInputStream data_stream = new DataInputStream (file_stream);
                    string ?line = null;
                    while ((line = data_stream.read_line (null, null)) != null) {
                        lines += "%s\n".printf (line);
                    }
                } catch (Error e) {
                    continue;
                }
                info ("Contents of %s:\n%s", path, lines);
                break;
            }

            // Log important environment variables
            EnvironmentVariable[] variables = {
                EnvironmentVariable ("XDG_CURRENT_DESKTOP"),
                EnvironmentVariable ("XDG_SESSION_DESKTOP"),
                EnvironmentVariable ("DESKTOP_SESSION"),
                EnvironmentVariable ("XDG_SESSION_TYPE"),
                EnvironmentVariable ("XDG_BACKEND"),
                EnvironmentVariable ("XDG_DATA_HOME"),
                EnvironmentVariable ("XDG_DATA_DIRS"),
                EnvironmentVariable ("SHELL"),
                // From: https://docs.gtk.org/gtk4/running.html
                EnvironmentVariable ("GTK_DEBUG"),
                EnvironmentVariable ("GTK_PATH"),
                EnvironmentVariable ("GTK_IM_MODULE"),
                EnvironmentVariable ("GTK_MEDIA"),
                EnvironmentVariable ("GTK_EXE_PREFIX"),
                EnvironmentVariable ("GTK_DATA_PREFIX"),
                EnvironmentVariable ("GTK_THEME"),
                EnvironmentVariable ("GDK_PIXBUF_MODULE_FILE"),
                EnvironmentVariable ("GDK_DEBUG"),
                EnvironmentVariable ("GSK_DEBUG"),
                EnvironmentVariable ("GDK_BACKEND"),
                EnvironmentVariable ("GDK_DISABLE"),
                EnvironmentVariable ("GDK_GL_DISABLE"),
                EnvironmentVariable ("GDK_VULKAN_DISABLE"),
                EnvironmentVariable ("GDK_WAYLAND_DISABLE"),
                EnvironmentVariable ("GSK_RENDERER"),
                EnvironmentVariable ("GSK_GPU_DISABLE"),
                EnvironmentVariable ("GSK_CACHE_TIMEOUT"),
                EnvironmentVariable ("GTK_CSD"),
                EnvironmentVariable ("GTK_A11Y"),
                EnvironmentVariable ("DESKTOP_STARTUP_ID"),
            };
            string[] envp = Environ.get ();
            string env_variables = "";
            foreach (unowned EnvironmentVariable variable in variables) {
                env_variables += "%s\n".printf (variable.to_string (envp));
            }
            info ("important environment variables:\n%s", env_variables);

            info ("Gtk4LayerShell version: %u.%u.%u",
                  GtkLayerShell.get_major_version (),
                  GtkLayerShell.get_minor_version (),
                  GtkLayerShell.get_micro_version ());
            info ("LayerShell version supported by compositor: %u",
                  GtkLayerShell.get_protocol_version ());
        }

        private static void print_help (string[] args) {
            print ("Usage:\n");
            print ("\t %s <OPTION>\n".printf (args[0]));
            print ("Help:\n");
            print ("\t -h, --help \t\t Show help options\n");
            print ("\t -v, --version \t\t Prints version\n");
            print ("Options:\n");
            print ("\t -s, --style \t\t Use a custom Stylesheet file\n");
            print ("\t -c, --config \t\t Use a custom config file\n");
            print ("\t --skip-system-css \t Skip trying to parse the packaged Stylesheet file."
                   + " Useful for CSS debugging\n");
            print ("\t --custom-system-css \t Pick a custom CSS file to use as the \"system\" CSS."
                   + " Useful for CSS debugging\n");
        }
    }
}
