namespace SwayNotificationCenter.Widgets {
    class BacklightUtil {

        [DBus (name = "org.freedesktop.login1.Session")]
        interface Login1 : Object {
            public abstract void set_brightness (string subsystem,
                                                 string name, uint32 brightness) throws GLib.Error;
        }

        string path_current;
        string path_max;
        File fd;

        int max;

        Login1 login1;
        string device;
        string subsystem;

        public signal void brightness_change (int percent);

        public BacklightUtil (string s, string d) {
            this.subsystem = s;
            this.device = d;

            path_current = Path.build_path (Path.DIR_SEPARATOR_S,
                                            "/sys", "class", subsystem, device, "brightness");
            path_max = Path.build_path (Path.DIR_SEPARATOR_S,
                                        "/sys", "class", subsystem, device, "max_brightness");
            fd = File.new_for_path (path_current);
            if (fd.query_exists ()) {
                set_max_value ();
            } else {
                this.brightness_change (-1);
                warning ("Could not find device %s\n", path_current);
            }

            try {
                // setup DBus for setting brightness
                login1 = Bus.get_proxy_sync (BusType.SYSTEM,
                                             "org.freedesktop.login1",
                                             "/org/freedesktop/login1/session/auto");
            } catch (Error e) {
                error ("Error %s\n", e.message);
            }
        }

        public void start () {
            if (fd.query_exists ()) {
                // get changes made while controlCenter not shown
                get_brightness ();
            } else {
                this.brightness_change (-1);
                warning ("Could not find device %s\n", path_current);
            }
        }

        public void set_brightness (float percent) {
            try {
                if (subsystem == "backlight") {
                    int actual = calc_actual (percent);
                    login1.set_brightness (subsystem, device, actual);
                } else {
                    login1.set_brightness (subsystem, device, (uint32) percent);
                }
            } catch (Error e) {
                error ("Error %s\n", e.message);
            }
        }

        // get current brightness and emit signal
        private void get_brightness () {
            try {
                var dis = new DataInputStream (fd.read ());
                string data = dis.read_line ();
                if (subsystem == "backlight") {
                    int val = calc_percent (int.parse (data));
                    this.brightness_change (val);
                } else {
                    this.brightness_change (int.parse (data));
                }
            } catch (Error e) {
                error ("Error %s\n", e.message);
            }
        }

        private void set_max_value () {
            try {
                File fd_max = File.new_for_path (path_max);
                DataInputStream dis_max = new DataInputStream (fd_max.read (null));
                string data = dis_max.read_line (null);
                max = int.parse (data);
            } catch (Error e) {
                error ("Error %s\n", e.message);
            }
        }

        private int calc_percent (int val) {
            return (int) Math.round (val * 100.0 / max);
        }

        private int calc_actual (float val) {
            return (int) Math.round (val * max / 100);
        }

        public int get_max_value () {
            return this.max;
        }
    }
}
