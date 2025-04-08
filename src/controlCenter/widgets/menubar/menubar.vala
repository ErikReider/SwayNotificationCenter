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

        Gtk.Box left_container;
        Gtk.Box right_container;

        List<ConfigObject ?> menu_objects;
        List<ToggleButton> toggle_buttons;

        public Menubar (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);
            set_orientation (Gtk.Orientation.VERTICAL);
            set_hexpand (true);

            Json.Object ? config = get_config (this);
            if (config != null) {
                parse_config_objects (config);
            }

            Gtk.Box topbar_container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            topbar_container.add_css_class ("menu-button-bar");
            append (topbar_container);

            left_container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                overflow = Gtk.Overflow.HIDDEN,
                hexpand = true,
                halign = Gtk.Align.START,
            };
            left_container.add_css_class ("widget-menubar-container");
            left_container.add_css_class ("start");
            topbar_container.append (left_container);
            right_container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                overflow = Gtk.Overflow.HIDDEN,
                hexpand = true,
                halign = Gtk.Align.END,
            };
            right_container.add_css_class ("widget-menubar-container");
            right_container.add_css_class ("end");
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
                    Gtk.Box container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                    if (obj.name != null) container.add_css_class (obj.name);

                    foreach (Action a in obj.actions) {
                        switch (a.type) {
                            case ButtonType.TOGGLE:
                                ToggleButton tb = new ToggleButton (a.label, a.command, a.update_command, a.active);
                                container.append (tb);
                                toggle_buttons.append (tb);
                                break;
                            default:
                                Gtk.Button b = new Gtk.Button.with_label (a.label);
                                b.clicked.connect (() => execute_command.begin (a.command));
                                container.append (b);
                                break;
                        }
                    }
                    switch (obj.position) {
                        case Position.LEFT:
                            left_container.append (container);
                            break;
                        case Position.RIGHT:
                            right_container.append (container);
                            break;
                    }
                    break;
                case MenuType.MENU:
                    Gtk.ToggleButton show_button = new Gtk.ToggleButton.with_label (obj.label);

                    Gtk.Box menu = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                    if (obj.name != null) menu.add_css_class (obj.name);

                    Gtk.Revealer r = new Gtk.Revealer ();
                    r.set_child (menu);
                    r.set_transition_duration (obj.animation_duration);
                    r.set_transition_type (obj.animation_type);
                    obj.revealer = r;

                    // Make sure that the toggle buttons state is always synced
                    // with the revealers visibility.
                    r.bind_property ("child-revealed",
                        show_button, "active", BindingFlags.SYNC_CREATE, null, null);

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
                                tb.set_hexpand (true);
                                menu.append (tb);
                                toggle_buttons.append (tb);
                                break;
                            default:
                                Gtk.Button b = new Gtk.Button.with_label (a.label);
                                b.set_hexpand (true);
                                b.clicked.connect (() => execute_command.begin (a.command));
                                menu.append (b);
                                break;
                        }
                    }

                    switch (obj.position) {
                        case Position.RIGHT:
                            right_container.append (show_button);
                            break;
                        case Position.LEFT:
                            left_container.append (show_button);
                            break;
                    }

                    append (r);
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
