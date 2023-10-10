namespace SwayNotificationCenter.Widgets {
    class ToggleButton : Gtk.ToggleButton {

        private string command;
        
        public ToggleButton (string label, string command, bool active) {
            this.command = command;
            this.label = label;

            if (active) {
                this.active = true;
            }

            this.toggled.connect (on_toggle);
        }

        private void on_toggle (Gtk.ToggleButton tb) {
            BaseWidget.execute_command (command);
        }
    }
}
