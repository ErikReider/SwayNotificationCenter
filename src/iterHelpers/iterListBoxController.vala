public class IterListBoxController : Object {
    public int length { get; private set; default = 0; }

    private List<Gtk.Widget> children = new List<Gtk.Widget> ();
    public unowned Gtk.ListBox list_box {
        get;
        private set;
    }

    public IterListBoxController (Gtk.ListBox list_box) {
        this.list_box = list_box;
    }

    private void on_add (Gtk.Widget child) {
        length++;
        child.destroy.connect (this.remove);
    }

    // NOTE: Not sorted
    public List<weak Gtk.Widget> get_children () {
        return children.copy ();
    }

    public void append (Gtk.Widget child) {
        children.append (child);
        list_box.append (children.last ().data);
        on_add (child);
    }

    public void prepend (Gtk.Widget child) {
        children.prepend (child);
        list_box.prepend (children.first ().data);
        on_add (child);
    }

    public void insert (Gtk.Widget child, int position) {
        children.insert (child, position);
        list_box.insert (children.nth (position).data, position);
        on_add (child);
    }

    public void remove (Gtk.Widget child) {
        children.remove (child);
        list_box.remove (child);
        length--;
    }
}
