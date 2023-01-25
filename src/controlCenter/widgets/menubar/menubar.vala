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

        void add_menu (ConfigObject o) {
            if (o.type == "buttons") {
                Gtk.Box container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                container.get_style_context ().add_class (o.name);

                foreach (Action a in o.actions) {
                    Gtk.Button b = new Gtk.Button.with_label (a.label);

                    b.clicked.connect (() => {
                        execute_command (a.command);
                    });

                    container.add (b);
                }
                if (o.position == "left") {
                    topbar_container.pack_start (container, false, false, 0);
                } else if (o.position == "right") {
                    topbar_container.pack_end (container, false, false, 0);
                } else {
                    debug ("Invalid position for menu item in config");
                }
            } else if (o.type == "menu") {

                Gtk.Button show_button = new Gtk.Button.with_label (o.label);

                Gtk.Box menu = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                menu.get_style_context ().add_class (o.name);
                menus.append (menu);
                o.hidden = true;

                show_button.clicked.connect (() => {
                    if (o.hidden) {
                        menus.foreach (m => m.hide ());
                        menu.show ();
                        o.hidden = !o.hidden;
                    } else {
                        menu.hide ();
                        o.hidden = !o.hidden;
                    }
                });

                foreach (var a in o.actions) {
                    Gtk.Button b = new Gtk.Button.with_label (a.label);
                    b.clicked.connect (() => {
                        execute_command (a.command);
                    });
                    menu.pack_start (b, true, true, 0);
                }

                if (o.position == "right") {
                    topbar_container.pack_end (show_button, false, false, 0);
                } else if (o.position == "left") {
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
            var el = config.get_members ();

            menu_objects = new ConfigObject[el.length ()];
            for (int i = 0; i < el.length (); i++) {
                string e = el.nth_data (i);
                Json.Object ? o = config.get_object_member (e);
                if (o != null) {

                    string ? type = get_prop<string> (o, "type");
                    if (type == null) {
                        type = "menu";
                        debug ("No type for menu-object given using default");
                    }

                    string ? pos = get_prop<string> (o, "position");
                    if (pos == null) {
                        pos = "right";
                        debug ("No type for menu-object given using default");
                    }

                    Json.Array ? actions = get_prop_array (o, "actions");
                    if (actions == null) {
                        debug ("Error parsing actions for menu-object");
                    }

                    string ? label = get_prop<string> (o, "label");
                    if (label == null) {
                        label = "Menu";
                        debug ("No label for menu-object given using default");
                    }

                    Action[] actions_list = parse_actions (actions);
                    menu_objects[i] = ConfigObject () {
                        name = e,
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
