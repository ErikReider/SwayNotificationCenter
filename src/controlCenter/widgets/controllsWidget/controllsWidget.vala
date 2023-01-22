using GLib;

namespace SwayNotificationCenter.Widgets {

    public struct ConfigObject {
        string? name;
        string? type;
        string? label;
        string? position;
        Action[] actions;
        bool hidden;
    }

    public struct Action {
        string? label;
        string? command;
    }

    public class ControllsWidget : BaseWidget {
        public override string widget_name {
            get {
                return "controlls";
            }
        }

        Gtk.Box controlls_widget;
        Gtk.Box topbar_container;
        Gtk.Box buttons_container;
        List<Gtk.Box> menus;

        ConfigObject[] menu_objects;
        ConfigObject[] button_objects;

        public ControllsWidget (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config(this);
            if(config != null){
                parse_config_objects(config);
            }

            controlls_widget = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            topbar_container = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            topbar_container.get_style_context().add_class("topbar");
            buttons_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            
            controlls_widget.add(topbar_container);

            foreach (var obj in menu_objects){
                add_menu(obj);
            }

            foreach (var obj in button_objects){
                add_buttons(obj);
            }


            pack_start(controlls_widget, true, true, 0);
            show_all();

            menus.foreach(m => m.hide());
        }

        void add_menu(ConfigObject o) {
            Gtk.Button show_button = new Gtk.Button.with_label(o.label);

            Gtk.Box menu = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            menu.get_style_context().add_class(o.name);
            menus.append(menu);
            o.hidden = true;
            
            show_button.clicked.connect(() => {
                if (o.hidden){
                    menus.foreach(m => m.hide());
                    menu.show();
                    o.hidden = !o.hidden;
                } else{
                    menu.hide();
                    o.hidden = !o.hidden;
                }
            });
            
            foreach(var a in o.actions){
                Gtk.Button b = new Gtk.Button.with_label(a.label);
                b.clicked.connect(() => {
                    execute_command(a.command);
                });
                menu.pack_start (b, true, true, 0);
                
            }
            if (o.position == "topbar-right") {
                topbar_container.pack_end(show_button, false, false, 0);
            } else if (o.position == "topbar-left") {
                topbar_container.pack_start(show_button, false, false, 0);
            } else {
                debug("Invalid position for menu item in config");
            }
            
            controlls_widget.add(menu);
        }

        void add_buttons(ConfigObject obj){
            if(obj.position == "topbar-left" || obj.position == "topbar-right"){
                Gtk.Box container = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
                container.get_style_context().add_class(obj.name);

                foreach (Action a in obj.actions){
                    Gtk.Button b = new Gtk.Button.with_label(a.label);

                    b.clicked.connect(() => {
                        execute_command(a.command);
                    });

                    container.add(b);
                }
                if(obj.position == "topbar-left") {
                    topbar_container.pack_start(container, false, false, 0);
                } else {
                    topbar_container.pack_end(container, false, false, 0);
                }

            } else {

                Gtk.FlowBox container = new Gtk.FlowBox();
                container.get_style_context().add_class(obj.name);
                
                foreach (Action a in obj.actions){
                    Gtk.Button b = new Gtk.Button.with_label(a.label);
                    
                    b.clicked.connect(() => {
                        execute_command(a.command);
                    });
                    container.insert(b, -1);
                }
                controlls_widget.add(container);
            }
        }

        protected void parse_config_objects(Json.Object config){
            var el = config.get_members();
            // track size of menu_objects and button_objests
            int menu_size = 0;
            int buttons_size = 0;

            menu_objects = new ConfigObject[menu_size];
            button_objects = new ConfigObject[buttons_size];
            foreach(var e in el){
                Json.Object? o = config.get_object_member(e);

                string? type = get_prop<string> (o, "type");
                if (type == null)
                    debug("Invalid config for controlls: Position needed");
                string? pos = get_prop<string> (o, "position");
                if(pos == null) 
                    debug("Invalid config for controlls: Position needed");
                Json.Array? actions = get_prop_array (o, "actions");
                    
                if (type == "menu"){
                    string? label = get_prop<string> (o, "label");
                    if(label == null)
                        debug("Invalid config for controls: label needed for type of 'menu'");
                    Action[] actionsList = parse_actions(actions);
                    menu_objects.resize(menu_size+1);
                    menu_objects[menu_size] = ConfigObject(){
                        name = e,
                        type = type,
                        label = label,
                        position = pos,
                        actions = actionsList,
                        hidden = true
                    };
                    menu_size += 1;
                } else if (type == "buttons"){
                    Action[] actionsList = parse_actions(actions);
                    button_objects.resize(buttons_size+1);
                    button_objects[buttons_size] = ConfigObject(){
                        name = e,
                        type = type,
                        position = pos,
                        actions = actionsList
                    };
                    buttons_size += 1;
                }
            }

        }

        protected Action[] parse_actions(Json.Array actions){
            Action[] res = new Action[actions.get_length()];
            for (int i = 0; i < actions.get_length(); i++){
                string? label = actions.get_object_element(i).get_member("label").get_string();
                if(label == null) debug("Error parsing actions-array");
                string? command = actions.get_object_element(i).get_member("command").get_string();
                if(command == null) debug("Error parsing actions-array");
                res[i] = Action() {
                    label = label,
                    command = command
                };
            }
            return res;
        }

    }
}