public class IterBox : Gtk.Box {
    public uint length { get; private set; default = 0; }

    private List<Gtk.Widget> children = new List<Gtk.Widget> ();

    public IterBox (Gtk.Orientation orientation, int spacing) {
        Object (orientation: orientation, spacing: spacing);
        set_name ("iterbox");
    }

    private void on_add (Gtk.Widget child) {
        length++;
        child.destroy.connect (() => {
            children.remove (child);
        });
    }

    public List<weak Gtk.Widget> get_children () {
        return children.copy ();
    }

    public new void append (Gtk.Widget child) {
        children.append (child);
        base.append (children.last ().data);
        on_add (child);
    }

    public new void prepend (Gtk.Widget child) {
        children.prepend (child);
        base.prepend (children.first ().data);
        on_add (child);
    }

    public new void remove (Gtk.Widget child) {
        children.remove (child);
        base.remove (child);
        length--;
    }
}
