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
    }

    public class Menubar : BaseWidget {
        public override string widget_name {
            get {
                return "menubar";
            }
        }

        Gtk.Box left_container;
        Gtk.Box right_container;

        List<ConfigObject ?> menu_objects;

        public Menubar (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);
            set_orientation (Gtk.Orientation.VERTICAL);

            Json.Object ? config = get_config (this);
            if (config != null) {
                parse_config_objects (config);
            }


            Gtk.Box topbar_container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            append (topbar_container);

            left_container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                css_classes = { "widget-menubar-container", "start" },
                overflow = Gtk.Overflow.HIDDEN,
                hexpand = true,
                halign = Gtk.Align.START,
            };
            topbar_container.append (left_container);
            right_container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                css_classes = { "widget-menubar-container", "end" },
                overflow = Gtk.Overflow.HIDDEN,
                hexpand = true,
                halign = Gtk.Align.END,
            };
            topbar_container.append (right_container);

            for (int i = 0; i < menu_objects.length (); i++) {
                unowned ConfigObject ? obj = menu_objects.nth_data (i);
                add_menu (ref obj);
            }

            foreach (var obj in menu_objects) {
                obj.revealer ?.set_reveal_child (false);
            }
        }

        void add_menu (ref unowned ConfigObject ? obj) {
            switch (obj.type) {
                case MenuType.BUTTONS:
                    Gtk.Box container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                        css_classes = { "widget-menubar-buttons", "widget-menubar-child" },
                        overflow = Gtk.Overflow.HIDDEN,
                    };
                    if (obj.name != null) container.add_css_class (obj.name);

                    foreach (Action action in obj.actions) {
                        Gtk.Button button = new Gtk.Button.with_label (action.label);
                        button.add_css_class ("widget-menubar-button");

                        button.clicked.connect (() => execute_command (action.command));

                        container.append (button);
                    }
                    switch (obj.position) {
                        case Position.LEFT:
                            left_container.prepend (container);
                            break;
                        case Position.RIGHT:
                            right_container.append (container);
                            break;
                    }
                    break;
                case MenuType.MENU:
                    Gtk.ToggleButton show_button = new Gtk.ToggleButton.with_label (obj.label);
                    show_button.add_css_class ("widget-menubar-button");
                    show_button.add_css_class ("widget-menubar-child");
                    if (obj.name != null) show_button.add_css_class (obj.name);

                    Gtk.Box menu = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                    print ("NAME: %s\n", obj.name);

                    Gtk.Revealer revealer = new Gtk.Revealer () {
                        child = menu,
                        css_classes = { "widget-menubar-menu" },
                        hexpand = true,
                        transition_duration = obj.animation_duration,
                        transition_type = obj.animation_type
                    };
                    obj.revealer = revealer;

                    show_button.clicked.connect (() => {
                        bool visible = !revealer.get_reveal_child ();
                        foreach (var o in menu_objects) {
                            o.revealer ?.set_reveal_child (false);
                        }
                        if (visible) {
                            // revealer.show ();
                            revealer.set_reveal_child (true);
                        } else {
                            revealer.set_reveal_child (false);
                            Timeout.add_once (revealer.transition_duration, () => {
                                // revealer.hide ();
                                return Source.REMOVE;
                            });
                        }
                    });

                    foreach (var a in obj.actions) {
                        Gtk.Button b = new Gtk.Button.with_label (a.label);
                        b.clicked.connect (() => execute_command (a.command));
                        menu.prepend (b);
                    }

                    switch (obj.position) {
                        case Position.RIGHT:
                            show_button.halign = Gtk.Align.START;
                            right_container.append (show_button);
                            break;
                        case Position.LEFT:
                            show_button.halign = Gtk.Align.END;
                            left_container.prepend (show_button);
                            break;
                    }

                    append (revealer);
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
                MenuType type = MenuType.BUTTONS;
                switch (key[0]) {
                    case "buttons":
                        type = MenuType.BUTTONS;
                        break;
                    case "menu":
                        type = MenuType.MENU;
                        break;
                    default:
                        info ("Invalid type for menu-object - valid options: 'menu' || 'buttons' using default");
                        break;
                }

                string name = key[1];

                string ? config_pos = get_prop<string> (obj, "position");
                Position pos = Position.RIGHT;
                switch (config_pos) {
                    case "right":
                        pos = Position.RIGHT;
                        break;
                    case "left":
                        pos = Position.LEFT;
                        break;
                    default:
                        pos = Position.RIGHT;
                        info ("No position for menu-object given using default");
                        break;
                }

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
            }
        }
    }
}
