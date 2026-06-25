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

        string day_format = "%A";
        string date_format = "%B %-d, %Y";

        public Calendar (string suffix) {
            base (suffix);

            Json.Object ?config = get_config (this);

            var container = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            container.add_css_class ("calendar-container");
            container.set_hexpand (true);

            day_label = new Gtk.Label (null);
            day_label.add_css_class ("day-label");
            day_label.set_halign (Gtk.Align.START);

            date_label = new Gtk.Label (null);
            date_label.add_css_class ("date-label");
            date_label.set_halign (Gtk.Align.START);

            calendar = new Gtk.Calendar ();
            calendar.set_hexpand (true);

            if (config != null) {
                bool show_day_label_found;
                bool ?show_day_label = get_prop<bool> (config, "show-day-label",
                                                       out show_day_label_found);
                if (show_day_label_found && show_day_label == false) {
                    day_label.set_visible (false);
                }

                bool show_date_label_found;
                bool ?show_date_label = get_prop<bool> (config, "show-date-label",
                                                        out show_date_label_found);
                if (show_date_label_found && show_date_label == false) {
                    date_label.set_visible (false);
                }

                bool show_heading_found;
                bool ?show_heading = get_prop<bool> (config, "show-heading",
                                                     out show_heading_found);
                if (show_heading_found) {
                    calendar.show_heading = show_heading;
                }

                bool show_day_names_found;
                bool ?show_day_names = get_prop<bool> (config, "show-day-names",
                                                       out show_day_names_found);
                if (show_day_names_found) {
                    calendar.show_day_names = show_day_names;
                }

                bool show_week_numbers_found;
                bool ?show_week_numbers = get_prop<bool> (config, "show-week-numbers",
                                                          out show_week_numbers_found);
                if (show_week_numbers_found) {
                    calendar.show_week_numbers = show_week_numbers;
                }

                string ?df = get_prop<string> (config, "day-format");
                if (df != null) {
                    day_format = df;
                }

                string ?dtf = get_prop<string> (config, "date-format");
                if (dtf != null) {
                    date_format = dtf;
                }
            }

            container.append (day_label);
            container.append (date_label);
            container.append (calendar);
            append (container);

            calendar.day_selected.connect (update_labels);
            calendar.next_month.connect (update_labels);
            calendar.prev_month.connect (update_labels);
            calendar.next_year.connect (update_labels);
            calendar.prev_year.connect (update_labels);
            reset_to_today ();
        }

        void update_marks (DateTime selected) {
            var today = new DateTime.now_local ();

            calendar.clear_marks ();

            if (selected.get_year () == today.get_year ()
                && selected.get_month () == today.get_month ()) {
                calendar.mark_day ((uint) today.get_day_of_month ());
            }
        }

        void reset_to_today () {
            var today = new DateTime.now_local ();
            calendar.select_day (today);
            update_labels ();
        }

        void update_labels () {
            var selected = calendar.get_date ();
            update_marks (selected);

            var dt = new DateTime.local ((int) selected.get_year (),
                                         (int) selected.get_month (),
                                         (int) selected.get_day_of_month (),
                                         0, 0, 0.0);
            day_label.set_label (dt.format (day_format));
            date_label.set_label (dt.format (date_format));
        }

        public override void on_cc_visibility_change (bool value) {
            if (value) {
                reset_to_today ();
            }
        }
    }
}
