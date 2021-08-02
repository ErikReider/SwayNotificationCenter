namespace SwayNotificatonCenter {
    [GtkTemplate (ui = "/org/erikreider/sway-notification-center/controlCenter/topAction/topAction.ui")]
    class TopAction : Gtk.Box {

        [GtkChild]
        unowned Gtk.Label title;

        public TopAction (string title_text, Gtk.Widget action, bool is_title = false) {
            this.title.set_text (title_text);
            var attr = new Pango.AttrList ();
            if (is_title) attr.insert (new Pango.AttrSize (16000));
            this.title.set_attributes (attr);
            this.title.set_can_focus (false);

            action.valign = Gtk.Align.CENTER;
            action.set_can_focus (false);
            this.pack_end (action, false);

            this.show_all ();
        }
    }
}
