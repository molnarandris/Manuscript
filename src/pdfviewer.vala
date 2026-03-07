public class Manuscript.PdfViewer : Gtk.Widget, Gtk.Scrollable {

    public signal void synctex_back (string path, int p, double x, double y);

    private PdfDocument? document;

    public int spacing = 5;

    public double scale = 1.4;
    private double prev_zoom_gesture_scale = 1;

    private Gtk.Adjustment _hadjustment = new Gtk.Adjustment (0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    public Gtk.Adjustment hadjustment {
        get {
            return _hadjustment;
        }
        construct set {
            set_adjustment(ref _hadjustment, value);
        }
    }
    private Gtk.Adjustment _vadjustment = new Gtk.Adjustment (0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    public Gtk.Adjustment vadjustment {
        get {
            return _vadjustment;
        }
        construct set {
            set_adjustment(ref _vadjustment, value);
        }
    }
    public Gtk.ScrollablePolicy hscroll_policy {get; set; default = Gtk.ScrollablePolicy.MINIMUM;}
    public Gtk.ScrollablePolicy vscroll_policy {get; set; default = Gtk.ScrollablePolicy.MINIMUM;}

    private Gtk.EventControllerScroll scroll_controller;
    private Gtk.GestureZoom zoom_controller;

    public PdfViewer () {
    }

    construct {
        zoom_controller = new Gtk.GestureZoom ();
        zoom_controller.begin.connect (zoom_gesture_begin_cb);
        zoom_controller.scale_changed.connect (zoom_gesture_scale_changed_cb);
        add_controller (zoom_controller);

        scroll_controller = new Gtk.EventControllerScroll (Gtk.EventControllerScrollFlags.VERTICAL);
        scroll_controller.scroll.connect (scroll_cb);
        add_controller (scroll_controller);

    }

    private void set_adjustment (ref Gtk.Adjustment adjustment, Gtk.Adjustment? value) {
        adjustment.value_changed.disconnect (adjustment_value_changed);
        adjustment = value ?? new Gtk.Adjustment (0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
        adjustment.value_changed.connect (adjustment_value_changed);
        adjustment_value_changed();
    }

    private void adjustment_value_changed() {
        queue_allocate ();
    }

    public bool get_border (out Gtk.Border border) {
        border = Gtk.Border () {top = 0, bottom = 0, left = 0, right = 0};
        return false;
    }

    private Gtk.Allocation get_page_extent(int index) {
        var page = document.get_page(index);
        double w, h;
        page.get_size (out w, out h);
        Gtk.Allocation extent = {0, 0, 0, 0};
        extent.y = (int) (document.y_offsets[index] * scale) + index * spacing;
        extent.x = (int) ((document.width - w) * scale * 0.5);
        extent.width = (int) (w * scale);
        extent.height = (int) (h * scale);
        return extent;
    }

    public override void size_allocate (int width, int height, int baseline) {
        hadjustment.freeze_notify ();
        vadjustment.freeze_notify ();

        configure_adjustments();

        Gtk.Allocation view_area = {0, 0, width, height};

        for (var child = get_first_child(); child!=null; child = child.get_next_sibling()) {
            var page = child as Manuscript.Pdfpage;
            Gtk.Allocation page_area = get_page_extent(page.index);
            page_area.x -= (int) hadjustment.value;
            page_area.y -= (int) vadjustment.value;

            int no_baseline = -1;
            bool visible = page_area.intersect (view_area, null);
            child.set_child_visible (visible);
            if (visible) child.allocate_size (page_area, no_baseline);
        }

        hadjustment.thaw_notify ();
        vadjustment.thaw_notify ();
    }

    public override void measure (Gtk.Orientation orientation, int for_size,
                                  out int minimum, out int natural,
                                  out int minimum_baseline, out int natural_baseline) {
        minimum_baseline = -1;
        natural_baseline = -1;
        if (orientation == Gtk.Orientation.HORIZONTAL) {
            minimum = 0;
            natural = (int) (document.width * scale);
        } else {
            minimum = 0;
            natural = (int) (document.height * scale + document.n_pages * spacing);
        }
    }

    public override void snapshot (Gtk.Snapshot snapshot) {
        var w = get_width ();
        var h = get_height ();
        var rect = Graphene.Rect().init (0, 0, w, h);

        snapshot.push_clip (rect);
        base.snapshot(snapshot);
        snapshot.pop ();
    }

    private void remove_children () {
        Gtk.Widget? child = null;
        while ((child = get_first_child () as Gtk.Widget) !=null ) {
            child.unparent ();
            var page = child as Manuscript.Pdfpage;
        }
    }

    public void set_path (string path) throws Error {
        remove_children ();

        try{
            document = new PdfDocument (path);
        } catch (Error e) {
            document = null;
            throw (e);
        }

        for (int i = 0; i < document.n_pages; i++) {
            var page = new Manuscript.Pdfpage (document.get_page (i));
            page.insert_before (this, null);
            page.synctex_back.connect ((p,x,y) => {
                synctex_back(this.document.path, p, x, y);
                message("Double click at x = %g, y = %g on page %d", x,y,p);
            });
        }
        configure_adjustments();
    }

    private void configure_adjustments() {
        double val, lower, upper, step_increment, page_increment, page_size;
        double allocated_width = this.get_width();
        double allocated_height = this.get_height();
        lower = 0;
        step_increment = 10;

        val = hadjustment.value;
        upper = document.width * scale;
        page_size = Math.fmin (upper, allocated_width);
        page_increment = page_size * 0.9;
        hadjustment.configure (val, lower, upper, step_increment, page_increment, page_size);

        val = vadjustment.value;
        upper = document.height *scale + document.n_pages * spacing;
        page_size = Math.fmin (upper, allocated_height);
        page_increment = page_size * 0.9;
        vadjustment.configure (val, lower, upper, step_increment, page_increment, page_size);
    }

    public void zoom_gesture_begin_cb (Gdk.EventSequence? sequence) {
        prev_zoom_gesture_scale = 1;
    }

    public void zoom_gesture_scale_changed_cb (double zoom_gesture_scale) {
        double x=0, y=0;
        zoom_controller.get_bounding_box_center(out x, out y);
        var factor = zoom_gesture_scale - prev_zoom_gesture_scale + 1;
        zoom (factor, x, y);
        prev_zoom_gesture_scale = zoom_gesture_scale;
    }

    public void zoom (double factor, double center_x, double center_y) {
        scale *= factor;
        var h = hadjustment.get_value ();
        var v = vadjustment.get_value ();
        for (var child = get_first_child(); child!=null; child = child.get_next_sibling()) {
            var page = child as Manuscript.Pdfpage;
            page.scale = scale;
        }
        queue_allocate();
        hadjustment.set_value ((h+center_x) * factor - center_x);
        vadjustment.set_value ((v+center_y) * factor - center_y);
    }

    public bool scroll_cb (double dx, double dy) {
        var state = scroll_controller
                    .get_current_event ()
                    .get_modifier_state ();
        var ctrl = (bool) (state & Gdk.ModifierType.CONTROL_MASK);
        var factor = dy > 0 ? 1.05 : 0.95;
        if (ctrl) zoom (factor, 0, 0);
        return ctrl;
    }

    public void add_synctex_rectangles (Gee.HashMap<int, Gee.ArrayList<Graphene.Rect?>> synctex_results) {

        var min_page = int.MAX;
        foreach (var page_num in synctex_results.keys) {
            if (min_page < 0) min_page = page_num;
            min_page = page_num < min_page ? page_num : min_page;
            var list = synctex_results.get (page_num);
            var page = get_first_child () as Manuscript.Pdfpage;
            for (int i = 0; i < page_num; i++) {
                page = page.get_next_sibling ()  as Manuscript.Pdfpage;
            }
            page.add_synctex_rectangles (list);
        }
        if (min_page == int.MAX) return;
        var list = synctex_results.get (min_page);
        var min_y = float.MAX;
        foreach (var rect in list) {
            min_y = rect.origin.y < min_y ? rect.origin.y : min_y;
        }
        if (min_y == float.MAX) min_y = 0;
        scroll_to(min_page, min_y);
    }

    public void scroll_to (int p, float y) {
        vadjustment.set_value ((document.y_offsets[p] + y)*scale - get_height () * 0.3);
    }

    protected override void dispose () {
        _hadjustment.value_changed.disconnect (adjustment_value_changed);
        _vadjustment.value_changed.disconnect (adjustment_value_changed);
        remove_children();
        base.dispose ();
    }
}


