namespace SwayNotificationCenter.Widgets.Todo {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/controlCenter/widgets/todo/todo_item.ui")]
    public class TodoItem : Gtk.Box {
        [GtkChild]
        unowned Gtk.Label class;
        [GtkChild]
        unowned Gtk.Label assignment;
        [GtkChild]
        unowned Gtk.Label due;
        [GtkChild]
        unowned Gtk.Image item_type;


        // public TodoSource source { construct; get; }

        private unowned Config todo_config;

        public TodoItem (TodoSource source, Config todo_config) {
            // Object (source: source);
            this.todo_config = todo_config;
            class.set_text(source.class);
            // class.set_justify (Gtk.Justification.LEFT);
             unowned Gtk.StateFlags state = class.get_style_context().get_state();
            var classColor = class.get_style_context ().get_color(state);
            Gdk.RGBA sourceColor = {
                red: 0,
                green: 0,
                blue: 0,
                alpha: 0
            };
            sourceColor.parse(source.color);
            classColor = sourceColor;
            class.override_color (Gtk.StateFlags.NORMAL, classColor);
            assignment.set_text(source.title);
            // assignment.set_justify (Gtk.Justification.LEFT);

            var dueFormat = new GLib.DateTime.from_iso8601 (source.due, new GLib.TimeZone.utc()).to_local ();

            due.set_text(dueFormat.format("Due %A, %B %-e, %Y at %R"));
            // due.set_justify (Gtk.Justification.LEFT);
            item_type.set_from_icon_name ("swaync-%s".printf(source.type), Gtk.IconSize.LARGE_TOOLBAR); 
            item_type.set_pixel_size(20);
   
        }

    }
}
