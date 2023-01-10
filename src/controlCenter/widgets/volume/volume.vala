using GLib;

namespace SwayNotificationCenter.Widgets {
    public class Volume : BaseWidget {
        public override string widget_name {
            get {
                return "volume";
            }
        }

        Gtk.Label label_widget;
        Gtk.Scale slider;

        string label = "Volume";

        public Volume (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config(this);
            if(config != null){
                string? l = get_prop<string> (config, "label");
                if(l!=null) this.label = l;
            }

            label_widget = new Gtk.Label (label);
            slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL,5,100,1);

            int volume = get_current_volume();
            slider.adjustment.value = volume;


            slider.adjustment.value_changed.connect (()=>{
                int val = (int)slider.adjustment.value;
                
                execute_command("pamixer --set-volume "+val.to_string());
                this.tooltip_text = val.to_string();
            });


            slider.draw_value = false;
            this.tooltip_text = slider.adjustment.value.to_string();

            add (label_widget);
            pack_start (slider, true, true, 0);


            show_all ();
        }

        private int get_current_volume(){
            string volume_value_command = "pamixer --get-volume" ;

            string volume_stdout;
            string volume_stderr;
            int volume_status;


            try{
                Process.spawn_command_line_sync (volume_value_command, out volume_stdout, out volume_stderr, out volume_status);
            } catch (SpawnError e){
                print ("Error: %s\n", e.message);
            }

            return int.parse(volume_stdout);
        }
    }
}