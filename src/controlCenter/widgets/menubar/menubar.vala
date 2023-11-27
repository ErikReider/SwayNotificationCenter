using GLib;

namespace SwayNotificationCenter.Widgets {

    public enum MenuType {
        BUTTONS,
        MENU
    }

    public enum Position {
        LEFT,
        RIGHT
    }
    public struct ConfigObject {
        string ? name;
        MenuType ? type;
        string ? label;
        Position ? position;
        Action[] actions;
        Gtk.Revealer ? revealer;
        int animation_duration;
        Gtk.RevealerTransitionType animation_type;
    }

    public struct Action {
        string ? label;
        string ? command;
        BaseWidget.ButtonType ? type;
        string ? update_command;
        bool ? active;
    }

    public class Menubar : BaseWidget {
        public override string widget_name {
            get {
                return "menubar";
            }
        }

        Gtk.Box menus_container;
        Gtk.Box topbar_container;

        List<ConfigObject ?> menu_objects;
        List<ToggleButton> toggle_buttons;

        public Menubar (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config (this);
            if (config != null) {
                parse_config_objects (config);
            }

            menus_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            topbar_container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            topbar_container.get_style_context ().add_class ("menu-button-bar");

            menus_container.add (topbar_container);

            for (int i = 0; i < menu_objects.length (); i++) {
                unowned ConfigObject ? obj = menu_objects.nth_data (i);
                add_menu (ref obj);
            }

            pack_start (menus_container, true, true, 0);
            show_all ();

            foreach (var obj in menu_objects) {
                obj.revealer ?.set_reveal_child (false);
            }
        }

        void add_menu (ref unowned ConfigObject ? obj) {
            switch (obj.type) {
                case MenuType.BUTTONS:
                    Gtk.Box container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                    if (obj.name != null) container.get_style_context ().add_class (obj.name);

                    foreach (Action a in obj.actions) {
                        switch (a.type) {
                            case ButtonType.TOGGLE:
                                ToggleButton tb = new ToggleButton (a.label, a.command, a.update_command, a.active);
                                container.add (tb);
                                toggle_buttons.append (tb);
                                break;
                            default:
                                Gtk.Button b = new Gtk.Button.with_label (a.label);
                                b.clicked.connect (() => execute_command.begin (a.command));
                                container.add (b);
                                break;
                        }
                    }
                    switch (obj.position) {
                        case Position.LEFT:
                            topbar_container.pack_start (container, false, false, 0);
                            break;
                        case Position.RIGHT:
                            topbar_container.pack_end (container, false, false, 0);
                            break;
                    }
                    break;
                case MenuType.MENU:
                    Gtk.Button show_button = new Gtk.Button.with_label (obj.label);

                    Gtk.Box menu = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                    if (obj.name != null) menu.get_style_context ().add_class (obj.name);

                    Gtk.Revealer r = new Gtk.Revealer ();
                    r.add (menu);
                    r.set_transition_duration (obj.animation_duration);
                    r.set_transition_type (obj.animation_type);
                    obj.revealer = r;

                    show_button.clicked.connect (() => {
                        bool visible = !r.get_reveal_child ();
                        foreach (var o in menu_objects) {
                            o.revealer ?.set_reveal_child (false);
                        }
                        r.set_reveal_child (visible);
                    });

                    foreach (var a in obj.actions) {
                        switch (a.type) {
                            case ButtonType.TOGGLE:
                                ToggleButton tb = new ToggleButton (a.label, a.command, a.update_command, a.active);
                                menu.pack_start (tb, true, true, 0);
                                toggle_buttons.append (tb);
                                break;
                            default:
                                Gtk.Button b = new Gtk.Button.with_label (a.label);
                                b.clicked.connect (() => execute_command.begin (a.command));
                                menu.pack_start (b, true, true, 0);
                                break;
                        }
                    }

                    switch (obj.position) {
                        case Position.RIGHT:
                            topbar_container.pack_end (show_button, false, false, 0);
                            break;
                        case Position.LEFT:
                            topbar_container.pack_start (show_button, false, false, 0);
                            break;
                    }

                    menus_container.add (r);
                    break;
            }
        }

        protected void parse_config_objects (Json.Object config) {
            var elements = config.get_members ();

            menu_objects = new List<ConfigObject ?> ();
            for (int i = 0; i < elements.length (); i++) {
                string e = elements.nth_data (i);
                Json.Object ? obj = config.get_object_member (e);

                if (obj == null) continue;

                string[] key = e.split ("#");
                string t = key[0];
                MenuType type = MenuType.BUTTONS;
                if (t == "buttons") type = MenuType.BUTTONS;
                else if (t == "menu") type = MenuType.MENU;
                else info ("Invalid type for menu-object - valid options: 'menu' || 'buttons' using default");

                string name = key[1];

                string ? p = get_prop<string> (obj, "position");
                Position pos;
                if (p != "left" && p != "right") {
                    pos = Position.RIGHT;
                    info ("No position for menu-object given using default");
                } else if (p == "right") pos = Position.RIGHT;
                else pos = Position.LEFT;

                Json.Array ? actions = get_prop_array (obj, "actions");
                if (actions == null) {
                    info ("Error parsing actions for menu-object");
                }

                string ? label = get_prop<string> (obj, "label");
                if (label == null) {
                    label = "Menu";
                    info ("No label for menu-object given using default");
                }

                int duration = int.max (0, get_prop<int> (obj, "animation-duration"));
                if (duration == 0) duration = 250;

                string ? animation_type = get_prop<string> (obj, "animation-type");
                if (animation_type == null) {
                    animation_type = "slide_down";
                    info ("No animation-type for menu-object given using default");
                }

                Gtk.RevealerTransitionType revealer_type;

                switch (animation_type) {
                    default:
                    case "none":
                        revealer_type = Gtk.RevealerTransitionType.NONE;
                        break;
                    case "slide_up":
                        revealer_type = Gtk.RevealerTransitionType.SLIDE_UP;
                        break;
                    case "slide_down":
                        revealer_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
                        break;
                }

                Action[] actions_list = parse_actions (actions);
                menu_objects.append (ConfigObject () {
                    name = name,
                    type = type,
                    label = label,
                    position = pos,
                    actions = actions_list,
                    revealer = null,
                    animation_duration = duration,
                    animation_type = revealer_type,
                });
            }
        }

        public override void on_cc_visibility_change (bool val) {
            if (!val) {
                foreach (var obj in menu_objects) {
                    obj.revealer ?.set_reveal_child (false);
                }
            } else {
                foreach (var tb in toggle_buttons) {
                    tb.on_update.begin ();
                }
            }
        }
    }
}
