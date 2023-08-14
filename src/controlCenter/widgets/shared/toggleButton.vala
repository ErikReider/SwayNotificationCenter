namespace SwayNotificationCenter.Widgets {
    class ToggleButton : Gtk.ToggleButton {

        private string command;
        public ToggleButton (string label, string command, bool active) {
            this.command = command;
            this.label = label;

            if (active) {
                this.get_style_context ().add_class ("active");
                this.active = true;
            }

            this.toggled.connect (on_toggle);
        }

        private void on_toggle (Gtk.ToggleButton tb) {
            BaseWidget.execute_command (command);
            if (tb.active)
                tb.get_style_context ().add_class ("active");
            else
                tb.get_style_context ().remove_class ("active");
        }
    }
}
