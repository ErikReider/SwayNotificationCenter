using GLib;

namespace SwayNotificationCenter.Widgets {

    public struct Config {
        string label;
        string command;
    }

    public class Powermenu : BaseWidget {
        public override string widget_name {
            get {
                return "powermenu";
            }
        }

        //  Gtk.Expander expander;
        Gtk.Button show_menu;
        Gtk.Button screenshot_btn;
        Gtk.Button show_powermode;
        Gtk.Box syscontrolls_container;
        Gtk.Box topbar_container;
        Gtk.Box powerbtn_container;
        Gtk.Box powermode_container;
        Gtk.FlowBox controlls_container;

        Gtk.Button[] pmode_button_array;

        bool power_menu_hidden = true;
        bool powermode_menu_hidden = true;

        // Defualt labels
        string powermenu_lbl;
        string screenshot_lbl;
        string screenshot_cmd;
        string powermode_lbl;
        bool power_menu = false;
        bool powermode_menu = false;

        // Config arrays
        Config[] power_buttons;
        Config[] controll_buttons;
        Config[] powermode_buttons;


        public Powermenu (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config(this);
            if(config != null){
                // Get labels
                string? sl = get_prop<string> (config, "screenshot-label");
                if(sl!=null) this.screenshot_lbl = sl;
                string? pl = get_prop<string> (config, "powermenu-label");
                if(pl!=null) this.powermenu_lbl = pl;
                string? pm = get_prop<string> (config, "powermode-label");
                if(pm!=null) this.powermode_lbl = pm;

                //  get functions to execute
                string? sc = get_prop<string> (config, "screenshot-command");
                if(sc!=null) this.screenshot_cmd = sc;

                Json.Array? power_buttons_json = get_prop_array (config, "power-buttons");
                if(power_buttons_json!=null){
                    power_buttons = new Config[power_buttons_json.get_length()];
                    parse_json_array(power_buttons, power_buttons_json);
                    power_menu = true;
                }

                Json.Array? controll_buttons_json = get_prop_array (config, "controll-buttons");
                if(controll_buttons_json != null){
                    controll_buttons = new Config[controll_buttons_json.get_length ()];
                    parse_json_array(controll_buttons, controll_buttons_json);
                }

                Json.Array? powermode_buttons_json = get_prop_array (config, "powermode-buttons");
                if(powermode_buttons_json != null){
                    powermode_buttons = new Config[powermode_buttons_json.get_length ()];
                    pmode_button_array = new Gtk.Button[power_buttons_json.get_length()];
                    parse_json_array(powermode_buttons, powermode_buttons_json);
                    powermode_menu = true;
                }
                
            }

            syscontrolls_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            if(screenshot_lbl != null || power_menu || powermode_menu ){
                topbar_container = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
                topbar_container.get_style_context().add_class("topbar");
                syscontrolls_container.add(topbar_container);

                if(screenshot_lbl != null) {
                    screenshot_btn = new Gtk.Button.with_label(screenshot_lbl);
                    screenshot_btn.clicked.connect(() => {
                        execute_command(screenshot_cmd);
                    });

                    topbar_container.pack_start(screenshot_btn, false, false, 0);
                }

                if(powermode_lbl != null) {
                    add_powermode_menu();
                }

                if(powermenu_lbl != null) {
                    add_power_menu();
                }

            }

            if(controll_buttons != null) {
                add_system_controll_menu();
            }

            pack_start(syscontrolls_container, true, true, 0);
            show_all ();
            if(power_menu) powerbtn_container.hide(); // add check if actually created (in case user didnt specify powerbtn in config)
            if(powermode_menu) powermode_container.hide();
        }

        private void parse_json_array(Config[] res, Json.Array array){
            for(int i = 0; i<array.get_length(); i++){
                string? s_label = array.get_object_element(i).get_member("label").get_string();
                if(s_label==null) debug ("error parsing json\n");
                string? s_command = array.get_object_element(i).get_member("command").get_string();
                if(s_command==null) debug("error parsing json\n");
                res[i] = Config() {
                    label = s_label,
                    command = s_command
                };
            }
        }

        private void add_power_menu() {
            powerbtn_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            powerbtn_container.get_style_context().add_class("power-buttons");

            show_menu = new Gtk.Button.with_label(powermenu_lbl);
            show_menu.clicked.connect(()=>{
                if(power_menu_hidden) {
                    powerbtn_container.show();
                    if(powermode_menu) powermode_container.hide();
                    power_menu_hidden = !power_menu_hidden;
                } else {
                    powerbtn_container.hide();
                    power_menu_hidden = !power_menu_hidden;
                }
            });

            foreach(Config btn_config in power_buttons){
                Gtk.Button button = new Gtk.Button.with_label(btn_config.label);
                button.clicked.connect(() => {
                    execute_command(btn_config.command);
                });
                powerbtn_container.pack_start (button, true, true, 0);
            }

            topbar_container.pack_end(show_menu, false, false, 0);

            syscontrolls_container.add(powerbtn_container);
        }

        private void add_powermode_menu() {
            powermode_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            powermode_container.get_style_context().add_class("powermode-buttons");

            show_powermode = new Gtk.Button.with_label(powermode_lbl);
            show_powermode.clicked.connect(() => {
                if(powermode_menu_hidden){
                    powermode_container.show();
                    if(power_menu) powerbtn_container.hide();
                    powermode_menu_hidden = !powermode_menu_hidden;
                } else {
                    powermode_container.hide();
                    powermode_menu_hidden = !powermode_menu_hidden;
                }
            });

            int i = 0;
            foreach(Config pmode_config in powermode_buttons){
                Gtk.Button button = new Gtk.Button.with_label(pmode_config.label);
                button.clicked.connect(() => {
                    execute_command(pmode_config.command);
                });
                powermode_container.pack_start(button, true, true, 0);
                pmode_button_array[i] = button;
                i++;
            }

            topbar_container.pack_start(show_powermode, false, false, 0);

            syscontrolls_container.add(powermode_container);
        }

        private void add_system_controll_menu() {
            controlls_container = new Gtk.FlowBox();
            controlls_container.get_style_context().add_class("controll-buttons");
            
            foreach(Config btn_config in controll_buttons){
                Gtk.Button button = new Gtk.Button.with_label(btn_config.label);
                button.clicked.connect(()=>{
                    execute_command(btn_config.command);
                });
                controlls_container.insert(button, -1);
            }


            syscontrolls_container.add(controlls_container);
        }
    }
}