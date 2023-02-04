namespace SwayNotificationCenter.Widgets {
    class BrightnessUtil {


        string pathname;
        File fd;
        FileMonitor monitor;
        ulong monitor_id;

        int max;

        public signal void brightness_change (int percent);

        public BrightnessUtil (string device) {
            pathname = Path.build_filename ("/sys/class/backlight/" + device + "/brightness");
            set_max_value ();
        }

        public void start () {
            fd = File.new_for_path (pathname);
            try {
                monitor = fd.monitor (FileMonitorFlags.NONE, null);

                monitor_id = monitor.changed.connect ((src, dest, event) => {
                    try {
                        var dis = new DataInputStream (src.read (null));
                        string data = dis.read_line (null);
                        int val = calc_percent (int.parse (data));
                        this.brightness_change (val);
                    } catch (Error e) {
                        warning ("Error %s\n", e.message);
                    }
                });
            } catch (Error e) {
                warning ("Error %s\n", e.message);
            }
        }

        public void close () {
            monitor.disconnect (monitor_id);
        }

        public void set_brightness (int percent) {
            int actual = calc_actual (percent);
        }

        private void set_max_value () {
            try {

                var path = Path.build_filename ("/sys/class/backlight/intel_backlight/max_brightness");
                File fd_max = File.new_for_path (path);
                DataInputStream dis_max = new DataInputStream (fd_max.read (null));
                string data = dis_max.read_line (null);
                max = int.parse (data);
            } catch (Error e) {
                warning ("Error: %s\n", e.message);
            }
        }

        private int calc_percent (int val) {
            return val * 100 / max;
        }

        private int calc_actual (int val) {
            return val * max / 100;
        }
    }
}