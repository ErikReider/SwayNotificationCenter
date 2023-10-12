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

            Json.Object ? config = get_config (this);
            if (config != null) {
                Json.Array a = get_prop_array (config, "actions");
                if (a != null) actions = parse_actions (a);
            }

            Gtk.FlowBox container = new Gtk.FlowBox ();
            container.set_selection_mode (Gtk.SelectionMode.NONE);
            pack_start (container, true, true, 0);

            // add action to container
            foreach (var act in actions) {
                if (act.type == ButtonType.TOGGLE) {
                    ToggleButton tb = new ToggleButton (act.label, act.command, act.update_command, act.active);
                    container.insert (tb, -1);
                    toggle_buttons.append (tb);
                } else {
                    Gtk.Button b = new Gtk.Button.with_label (act.label);
                    b.clicked.connect (() => execute_command.begin (act.command));
                    container.insert (b, -1);
                }
            }

            show_all ();
        }

        public override void on_cc_visibility_change (bool value) {
            if (!value) {
                foreach (var tb in toggle_buttons) {
                    tb.on_update.begin ();
                }
            }
        }
    }
}
