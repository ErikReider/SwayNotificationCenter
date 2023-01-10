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

        string label = "Brightness";
        string device;

        public Brightness (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config(this);
            if(config != null){
                string? l = get_prop<string> (config, "label");
                if(l!=null) this.label = l;
                string? d = get_prop<string> (config, "device");
                if(d!=null) this.device = d;
            }

            label_widget = new Gtk.Label (label);
            slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL,5,100,1);

            int brightness = get_current_brightness();
            slider.adjustment.value = brightness;


            slider.adjustment.value_changed.connect (()=>{
                int val = (int) slider.adjustment.value;

                string command = device!=null ? "brightnessctl -d " + device + " s "+val.to_string()+"% --quiet" : "brightnessctl s "+val.to_string()+"% --quiet";

                execute_command(command);
                this.tooltip_text = val.to_string();
            });

            slider.draw_value = false;
            this.tooltip_text = slider.adjustment.value.to_string();

            add (label_widget);
            pack_start (slider, true, true, 0);


            show_all ();
        }

        private int get_current_brightness(){
            string max_value_command = device!=null ? "brightnessctl -d " + device + " m" : "brightnessctl m";
            string current_value_command = device!=null ? "brightnessctl -d " + device + " g" : "brightnessctl g" ;

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