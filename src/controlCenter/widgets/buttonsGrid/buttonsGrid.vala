using GLib;

namespace SwayNotificationCenter.Widgets {

    public class ButtonsGrid : BaseWidget {
        public override string widget_name {
            get {
                return "buttons-grid";
            }
        }

        Action[] actions;
        List<ToggleButton> toggle_buttons;

        public ButtonsGrid (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Gtk.FlowBox container = new Gtk.FlowBox ();
            container.set_selection_mode (Gtk.SelectionMode.NONE);
            pack_start (container, true, true, 0);

            Json.Object ? config = get_config (this);
            if (config != null) {
                Json.Array a = get_prop_array (config, "actions");
                if (a != null) {
                    actions = parse_actions (a);
                }

                bool ? center = get_prop<bool> (config, "center");
                if (center != null && center) {
                    container.set_halign (Gtk.Align.CENTER);
                }

                int ? col_min = get_prop<int> (config, "column-min");
                if (col_min != null && col_min > 0) {
                    container.set_min_children_per_line (col_min);
                }

                int ? col_max = get_prop<int> (config, "column-max");
                if (col_max != null && col_max > 0) {
                    container.set_max_children_per_line (col_max);
                }
            }

            // add action to container
            foreach (var act in actions) {
                switch (act.type) {
                    case ButtonType.TOGGLE :
                        ToggleButton tb = new ToggleButton (act.label, act.command, act.update_command, act.active);
                        container.insert (tb, -1);
                        toggle_buttons.append (tb);
                        break;
                    default:
                        Gtk.Button b = new Gtk.Button.with_label (act.label);
                        b.clicked.connect (() => execute_command.begin (act.command));
                        container.insert (b, -1);
                        break;
                }
            }

            show_all ();
        }

        public override void on_cc_visibility_change (bool value) {
            if (value) {
                foreach (var tb in toggle_buttons) {
                    tb.on_update.begin ();
                }
            }
        }
    }
}
