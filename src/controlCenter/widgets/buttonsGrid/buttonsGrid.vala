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

            Gtk.FlowBox container = new Gtk.FlowBox ();
            container.set_selection_mode (Gtk.SelectionMode.NONE);
            pack_start (container, true, true, 0);

            // add action to container
            foreach (var act in actions) {
                Gtk.Button b = new Gtk.Button.with_label (act.label);

                b.clicked.connect (() => execute_command.begin (act.command));

                container.insert (b, -1);
            }

            show_all ();
        }
    }
}
