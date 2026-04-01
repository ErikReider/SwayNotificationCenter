using GLib;

namespace SwayNotificationCenter.Widgets {
    public class Calendar : BaseWidget {
        public override string widget_name {
            get {
                return "calendar";
            }
        }

        Gtk.Calendar calendar;
        Gtk.Label date_label;
        Gtk.Label day_label;

        public Calendar (string suffix) {
            base (suffix);

            Json.Object ?config = get_config (this);

            var container = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            container.set_margin_start (12);
            container.set_margin_end (12);
            container.set_margin_top (12);
            container.set_margin_bottom (12);
            container.set_hexpand (true);

            day_label = new Gtk.Label ("");
            day_label.add_css_class ("day-label");
            day_label.set_halign (Gtk.Align.START);

            date_label = new Gtk.Label ("");
            date_label.add_css_class ("date-label");
            date_label.set_halign (Gtk.Align.START);

            calendar = new Gtk.Calendar ();
            calendar.set_hexpand (true);
            calendar.add_css_class ("calendar-widget");

            if (config != null) {
                bool ?show_day_label = get_prop<bool> (config, "show-day-label", null);
                if (show_day_label == false) {
                    day_label.hide ();
                }

                bool ?show_date_label = get_prop<bool> (config, "show-date-label", null);
                if (show_date_label == false) {
                    date_label.hide ();
                }
            }

            container.append (day_label);
            container.append (date_label);
            container.append (calendar);
            append (container);

            calendar.day_selected.connect (update_labels);
            update_labels ();
        }

        void update_labels () {
            var now = new GLib.DateTime.now_local ();
            day_label.set_label (now.format ("%A"));
            date_label.set_label (now.format ("%B %-d, %Y"));
        }

        public override void on_cc_visibility_change (bool value) {
            if (value) {
                update_labels ();
            }
        }
    }
}
