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

        private async void on_toggle () {
            string msg = "";
            string[] env_additions = { "SWAYNC_TOGGLE_STATE=" + this.active.to_string () };
            yield Functions.execute_command (this.command, env_additions, out msg);
        }
    }
}
