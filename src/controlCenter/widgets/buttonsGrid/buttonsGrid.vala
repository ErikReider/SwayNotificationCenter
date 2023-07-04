using GLib;

namespace SwayNotificationCenter.Widgets {

    public class ButtonsGrid : BaseWidget {
        public override string widget_name {
            get {
                return "buttons-grid";
            }
        }

        Action[] actions;

        public ButtonsGrid (string suffix, SwayncDaemon swaync_daemon, NotiDaemon noti_daemon) {
            base (suffix, swaync_daemon, noti_daemon);

            Json.Object ? config = get_config (this);
            if (config != null) {
                Json.Array a = get_prop_array (config, "actions");
                if (a != null) actions = parse_actions (a);
            }

            if (actions.length == 0) {
                hide ();
                return;
            }

            Gtk.FlowBox container = new Gtk.FlowBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                hexpand = true,
            };
            prepend (container);

            // add action to container
            foreach (var act in actions) {
                Gtk.Button button = new Gtk.Button.with_label (act.label) {
                    css_classes = { "widget-buttons-grid-button" },
                };

                button.clicked.connect (() => execute_command (act.command));

                container.append (button);
            }
        }
    }
}
