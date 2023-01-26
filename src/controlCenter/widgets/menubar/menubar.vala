using GLib;

namespace SwayNotificationCenter.Widgets {

    public struct ConfigObject {
        string ? name;
        string ? type;
        string ? label;
        string ? position;
        Action[] actions;
        bool hidden;
    }

    public struct Action {
        string ? label;
        string ? command;
    }

    public class Menubar : BaseWidget {
        public override string widget_name {
            get {
                return "menubar";
            }
        }

        Gtk.Box menus_container;
        Gtk.Box topbar_container;
        List<Gtk.Box> menus;

        ConfigObject[] menu_objects;

        public Menubar (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config (this);
            if (config != null) {
                parse_config_objects (config);
            }

            menus_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            topbar_container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            topbar_container.get_style_context ().add_class ("topbar");

            menus_container.add (topbar_container);

            foreach (var obj in menu_objects) {
                add_menu (obj);
            }

            pack_start (menus_container, true, true, 0);
            show_all ();

            menus.foreach (m => m.hide ());
        }

        void add_menu (ConfigObject obj) {
            if (obj.type == "buttons") {
                Gtk.Box container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                container.get_style_context ().add_class (obj.name);

                foreach (Action a in obj.actions) {
                    Gtk.Button b = new Gtk.Button.with_label (a.label);

                    b.clicked.connect (() => {
                        execute_command (a.command);
                    });

                    container.add (b);
                }
                if (obj.position == "left") {
                    topbar_container.pack_start (container, false, false, 0);
                } else if (obj.position == "right") {
                    topbar_container.pack_end (container, false, false, 0);
                } else {
                    debug ("Invalid position for menu item in config");
                }
            } else if (obj.type == "menu") {

                Gtk.Button show_button = new Gtk.Button.with_label (obj.label);

                Gtk.Box menu = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                menu.get_style_context ().add_class (obj.name);
                menus.append (menu);
                obj.hidden = true;

                show_button.clicked.connect (() => {
                    if (obj.hidden) {
                        menus.foreach (m => m.hide ());
                        menu.show ();
                        obj.hidden = !obj.hidden;
                    } else {
                        menu.hide ();
                        obj.hidden = !obj.hidden;
                    }
                });

                foreach (var a in obj.actions) {
                    Gtk.Button b = new Gtk.Button.with_label (a.label);
                    b.clicked.connect (() => {
                        execute_command (a.command);
                    });
                    menu.pack_start (b, true, true, 0);
                }

                if (obj.position == "right") {
                    topbar_container.pack_end (show_button, false, false, 0);
                } else if (obj.position == "left") {
                    topbar_container.pack_start (show_button, false, false, 0);
                } else {
                    debug ("Invalid position for menu item in config");
                }

                menus_container.add (menu);
            } else {
                debug ("Invalid type for menu-object");
            }
        }

        protected void parse_config_objects (Json.Object config) {
            var elements = config.get_members ();

            menu_objects = new ConfigObject[elements.length ()];
            for (int i = 0; i < elements.length (); i++) {
                string e = elements.nth_data (i);
                Json.Object ? obj = config.get_object_member (e);
                if (obj != null) {
                    string[] key = e.split ("#");

                    string type = key[0];
                    string name = key[1];

                    string ? pos = get_prop<string> (obj, "position");
                    if (pos == null) {
                        pos = "right";
                        debug ("No type for menu-object given using default");
                    }

                    Json.Array ? actions = get_prop_array (obj, "actions");
                    if (actions == null) {
                        debug ("Error parsing actions for menu-object");
                    }

                    string ? label = get_prop<string> (obj, "label");
                    if (label == null) {
                        label = "Menu";
                        debug ("No label for menu-object given using default");
                    }

                    Action[] actions_list = parse_actions (actions);
                    menu_objects[i] = ConfigObject () {
                        name = name,
                        type = type,
                        label = label,
                        position = pos,
                        actions = actions_list,
                        hidden = true
                    };
                }
            }
        }
    }
}
