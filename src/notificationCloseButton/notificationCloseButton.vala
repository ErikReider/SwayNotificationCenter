namespace SwayNotificationCenter {
    public class NotificationCloseButton : Adw.Bin {
        Gtk.Revealer revealer;
        Gtk.Button button;

        construct {
            valign = Gtk.Align.START;
            // TODO: Configurable
            halign = Gtk.Align.END;

            revealer = new Gtk.Revealer () {
                transition_type = Gtk.RevealerTransitionType.CROSSFADE,
                reveal_child = false,
            };
            revealer.notify["child-revealed"].connect (() => {
                set_visible (revealer.reveal_child);
            });
            set_child (revealer);

            button = new Gtk.Button.from_icon_name ("swaync-close-symbolic") {
                has_frame = false,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
            };
            button.add_css_class ("close-button");
            button.add_css_class ("circular");
            button.clicked.connect (click_cb);
            revealer.set_child (button);
        }

        private void click_cb () {
            clicked ();
        }

        public signal void clicked ();

        public void set_reveal (bool state) {
            if (state == revealer.reveal_child) {
                set_visible (state);
                return;
            }

            if (state) {
                set_visible (true);
            }
            revealer.set_reveal_child (state);
        }

        public void set_transition_duration (uint duration) {
            revealer.set_transition_duration (duration);
        }
    }
}
