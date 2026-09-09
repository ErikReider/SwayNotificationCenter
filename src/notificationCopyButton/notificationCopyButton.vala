namespace SwayNotificationCenter {
    /**
     * Icon button that copies a notification's summary and body to the
     * clipboard. Sibling of NotificationCloseButton, but always visible:
     * the point of the button is that the action is discoverable.
     */
    public class NotificationCopyButton : Adw.Bin {
        Gtk.Button button;

        construct {
            valign = Gtk.Align.CENTER;
            halign = Gtk.Align.CENTER;

            button = new Gtk.Button.from_icon_name ("swaync-copy-symbolic") {
                has_frame = false,
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                tooltip_text = "Copy notification text",
            };
            button.add_css_class ("copy-button");
            button.add_css_class ("circular");
            button.clicked.connect (click_cb);
            set_child (button);
        }

        private void click_cb () {
            clicked ();
        }

        public signal void clicked ();

        /**
         * Swaps the icon for a checkmark as click confirmation. Both icons
         * share the same 16x16 canvas, so nothing moves. There is no swap
         * back: the notification is dismissed right after.
         */
        public void show_confirm () {
            button.set_icon_name ("swaync-copy-confirm-symbolic");
            button.set_tooltip_text ("Copied");
        }
    }
}
