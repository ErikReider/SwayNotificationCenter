namespace SwayNotificationCenter.Widgets {
    class ToggleButton : Gtk.ToggleButton {

        private string command;
        private string update_command;
        private ulong handler_id;

        public ToggleButton (string label, string command, string update_command, bool active) {
            this.command = command;
            this.update_command = update_command;
            this.label = label;

            if (active) {
                this.active = true;
            }

            this.handler_id = this.toggled.connect (on_toggle);
        }

        private async void on_toggle () {
            string msg = "";
            string[] env_additions = { "SWAYNC_TOGGLE_STATE=" + this.active.to_string () };
            yield Functions.execute_command (this.command, env_additions, out msg);
        }

        public async void on_update () {
            if (update_command == "") return;
            string msg = "";
            string[] env_additions = { "SWAYNC_TOGGLE_STATE=" + this.active.to_string () };
            yield Functions.execute_command (this.update_command, env_additions, out msg);
            try {
              // remove trailing whitespaces
              Regex regex = new Regex ("\\s+$");
              string res = regex.replace (msg, msg.length, 0, "");
              GLib.SignalHandler.block (this, this.handler_id);
              if (res.up () == "TRUE") {
                this.active = true;
              } else {
                this.active = false;
              }
              GLib.SignalHandler.unblock (this, this.handler_id);
            } catch (RegexError e) {
              stderr.printf ("RegexError: %s\n", e.message);
            }
        }
    }
}
