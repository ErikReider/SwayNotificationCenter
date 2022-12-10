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

        string text = "";

        public Volume (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            label_widget = new Gtk.Label (text);
            slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL,5,100,1);

            int volume = get_current_volume();
            slider.adjustment.value = volume;


            slider.adjustment.value_changed.connect (()=>{
                string set_stdout;
                string set_stderr;
                int set_status;

                try{
                    Process.spawn_command_line_sync("pamixer --set-volume "+slider.adjustment.value.to_string(), out set_stdout, out set_stderr, out set_status);
                } catch(SpawnError e){
                    print ("Error: %s\n", e.message);
                }

            });

            label_widget.set_justify (Gtk.Justification.LEFT);
            label_widget.set_alignment (0, 0);

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