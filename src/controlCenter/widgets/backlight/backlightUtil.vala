namespace SwayNotificationCenter.Widgets {
    class BacklightUtil {

        [DBus (name = "org.freedesktop.login1.Session")]
        interface Login1 : Object {
            public abstract void set_brightness (string subsystem, string name, uint32 brightness) throws GLib.Error;
        }


        string path_current;
        string path_max;
        File fd;
        FileMonitor monitor;
        ulong monitor_id;

        int max;

        Login1 login1;
        string device;

        public signal void brightness_change (int percent);

        public BacklightUtil (string d) {
            this.device = d;

            path_current = Path.build_filename ("/sys/class/backlight/" + device + "/brightness");
            path_max = Path.build_filename ("/sys/class/backlight/" + device + "/max_brightness");
            set_max_value ();

            try {
                // setup DBus for setting brightness
                login1 = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.login1", "/org/freedesktop/login1/session/auto");
            } catch (Error e) {
                error ("Error %s\n", e.message);
            }
        }

        public void start () {
            fd = File.new_for_path (path_current);

            // get changes made while controlCenter not shown
            get_brightness ();

            // connect monitor to monitor changes
            try {
                monitor = fd.monitor (FileMonitorFlags.NONE, null);

                monitor_id = monitor.changed.connect ((src, dest, event) => {
                    get_brightness ();
                });
            } catch (Error e) {
                error ("Error %s\n", e.message);
            }
        }

        public void close () {
            monitor.disconnect (monitor_id);
        }

        public void set_brightness (float percent) {
            try {
                int actual = calc_actual (percent);
                login1.set_brightness ("backlight", device, actual);
            } catch (Error e) {
                error ("Error %s\n", e.message);
            }
        }

        // get current brightness and emit signal
        private void get_brightness () {
            try {
                var dis = new DataInputStream (fd.read (null));
                string data = dis.read_line (null);
                int val = calc_percent (int.parse (data));
                this.brightness_change (val);
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
            return val * 100 / max;
        }

        private int calc_actual (float val) {
            return (int) val * max / 100;
        }
    }
}