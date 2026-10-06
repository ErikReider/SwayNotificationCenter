using GLib;

namespace SwayNotificationCenter.Widgets {
    public class ButtonsGrid : BaseWidget {
        public override string widget_name {
            get {
                return "buttons-grid";
            }
        }

        Action[] actions;
        // 7 is the default Gtk.FlowBox.max_children_per_line
        int buttons_per_row = 7;
        List<ToggleButton> toggle_buttons;
        HashTable<Gtk.Button, string> label_commands =
            new HashTable<Gtk.Button, string> (direct_hash, direct_equal);

        public ButtonsGrid (string suffix) {
            base (suffix);

            Json.Object ?config = get_config (this);
            if (config != null) {
                Json.Array a = get_prop_array (config, "actions");
                if (a != null) {
                    actions = parse_actions (a);
                }

                bool bpr_found = false;
                int bpr = get_prop<int> (config, "buttons-per-row", out bpr_found);
                if (bpr_found) {
                    buttons_per_row = bpr;
                }
            }

            Gtk.FlowBox container = new Gtk.FlowBox ();
            container.set_max_children_per_line (buttons_per_row);
            container.set_selection_mode (Gtk.SelectionMode.NONE);
            container.set_hexpand (true);
            append (container);

            // add action to container
            foreach (var act in actions) {
                switch (act.type) {
                    case ButtonType.TOGGLE :
                        ToggleButton tb = new ToggleButton (act.label, act.command,
                                                            act.update_command, act.active);
                        container.insert (tb, -1);
                        toggle_buttons.append (tb);
                        if (act.label_command != "") {
                            label_commands.insert (tb, act.label_command);
                        }
                        break;
                    default:
                        Gtk.Button b = new Gtk.Button.with_label (act.label);
                        string label_command = act.label_command;
                        b.clicked.connect (() => on_click.begin (b, act.command, label_command));
                        container.insert (b, -1);
                        if (label_command != "") {
                            label_commands.insert (b, label_command);
                        }
                        break;
                }
            }

            update_labels ();
        }

        private async void on_click (Gtk.Button button, string command, string label_command) {
            yield execute_command (command);

            if (label_command != "") {
                yield update_label (button, label_command);
            }
        }

        private async void update_label (Gtk.Button button, string label_command) {
            string msg = "";
            bool success = yield Functions.execute_command (label_command, {}, out msg);

            string label = msg.strip ();
            if (success && label != "") {
                button.set_label (label);
            }
        }

        private void update_labels () {
            label_commands.foreach ((button, label_command) => {
                update_label.begin (button, label_command);
            });
        }

        public override void on_cc_visibility_change (bool value) {
            if (value) {
                foreach (var tb in toggle_buttons) {
                    tb.on_update.begin ();
                }
                update_labels ();
            }
        }
    }
}
