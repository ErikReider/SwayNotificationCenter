public class Underlay : Gtk.Widget {
    protected unowned Gtk.Widget _child = null;
    public unowned Gtk.Widget child {
        get {
            return _child;
        }
        set {
            _child = value;
            set_children ();
        }
    }

    protected unowned Gtk.Widget _underlay_child = null;
    public unowned Gtk.Widget underlay_child {
        get {
            return _underlay_child;
        }
        set {
            _underlay_child = value;
            set_children ();
        }
    }

    private void set_children () {
        if (_underlay_child != null) {
            _underlay_child.unparent ();
            _underlay_child.insert_after (this, null);
        }

        if (_child != null) {
            _child.unparent ();
            _child.insert_after (this, _underlay_child);
        }
    }

    /*
     * Overrides
     */

    protected override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    protected override void measure (Gtk.Orientation orientation, int for_size,
                                     out int minimum, out int natural,
                                     out int minimum_baseline, out int natural_baseline) {
        minimum = 0;
        natural = 0;
        minimum_baseline = -1;
        natural_baseline = -1;

        int child_min, child_nat;

        if (!child.visible) {
            return;
        }

        child.measure (orientation, for_size,
                       out child_min, out child_nat, null, null);

        minimum = int.max (minimum, child_min);
        natural = int.max (natural, child_nat);
    }

    protected override void size_allocate (int width, int height, int baseline) {
        if (child != null && child.should_layout ()) {
            child.allocate (width, height, baseline, null);
        }

        if (underlay_child != null && underlay_child.should_layout ()) {
            underlay_child.allocate (width, height, baseline, null);
        }
    }
}
