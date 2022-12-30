using GLib;

namespace SwayNotificationCenter.Widgets {
    public class Brightness : BaseWidget {
        public override string widget_name {
            get {
                return "brightness";
            }
        }

        Gtk.Label label_widget;
        Gtk.Scale slider;

        string text = "";

        public Brightness (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            label_widget = new Gtk.Label (text);
            slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL,5,100,1);

            int brightness = get_current_brightness();
            slider.adjustment.value = brightness;


            slider.adjustment.value_changed.connect (()=>{
                string set_stdout;
                string set_stderr;
                int set_status;

                int val = (int) slider.adjustment.value;

                try{
                    Process.spawn_command_line_sync("brightnessctl s "+val.to_string()+"%", out set_stdout, out set_stderr, out set_status);
                    this.tooltip_text = val.to_string();
                } catch(SpawnError e){
                    print ("Error: %s\n", e.message);
                }

            });

            slider.draw_value = false;
            this.tooltip_text = slider.adjustment.value.to_string();

            add (label_widget);
            pack_start (slider, true, true, 0);


            show_all ();
        }

        private int get_current_brightness(){
            string max_value_command = "brightnessctl -d intel_backlight m" ;
            string current_value_command = "brightnessctl -d intel_backlight g" ;

            string max_stdout;
            string max_stderr;
            int max_status;


            string current_stdout;
            string current_stderr;
            int current_status;

            try{
                Process.spawn_command_line_sync (max_value_command, out max_stdout, out max_stderr, out max_status);
            } catch (SpawnError e){
                print ("Error: %s\n", e.message);
            }
            try {
                Process.spawn_command_line_sync (current_value_command, out current_stdout, out current_stderr, out current_status);
            } catch (SpawnError e){
                print ("Error: %s\n", e.message);
            }

            return int.parse(current_stdout) * 100 / int.parse(max_stdout);
        }
    }
}