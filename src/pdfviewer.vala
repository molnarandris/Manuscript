public class Manuscript.PdfViewer : Gtk.Widget {

    private PdfDocument? document;

    public int spacing = 5;

    public double zoom_level = 1.4;
    private double prev_zoom_gesture_scale = 1;

    private Gtk.EventControllerScroll scroll_controller;
    private Gtk.GestureZoom zoom_controller;

    public PdfViewer () {
    }

    construct {
        var layout = new Gtk.BoxLayout (Gtk.Orientation.VERTICAL);
        layout.set_spacing (spacing);
        set_layout_manager(layout);

        zoom_controller = new Gtk.GestureZoom ();
        zoom_controller.begin.connect (zoom_gesture_begin_cb);
        zoom_controller.scale_changed.connect (zoom_gesture_scale_changed_cb);
        add_controller (zoom_controller);

        scroll_controller = new Gtk.EventControllerScroll (Gtk.EventControllerScrollFlags.VERTICAL);
        scroll_controller.scroll.connect (scroll_cb);
        add_controller (scroll_controller);

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
        child = get_first_child () as Gtk.Widget;
        while (child != null) {
            child.unparent ();
            child = get_first_child () as Gtk.Widget;
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
            var overlay = new Gtk.Overlay ();
            overlay.set_child (page);
            overlay.insert_before (this, null);
        }
    }

    public void zoom_gesture_begin_cb (Gdk.EventSequence? sequence) {
        prev_zoom_gesture_scale = 1;
    }

    public void zoom_gesture_scale_changed_cb (double scale) {
        double x=0,y=0;
        zoom_controller.get_bounding_box_center(out x, out y);
        var factor = scale - prev_zoom_gesture_scale + 1;
        zoom (factor, x, y);
        prev_zoom_gesture_scale = scale;
    }

    public void zoom (double factor, double center_x, double center_y) {
        zoom_level *= factor;
        var scroll = get_ancestor (typeof(Gtk.ScrolledWindow)) as Gtk.ScrolledWindow;
        var h = scroll.get_hadjustment ().get_value ();
        var v = scroll.get_vadjustment ().get_value ();
        var overlay = get_first_child () as Gtk.Overlay;
        while (overlay != null) {
            var page = overlay.get_child () as Manuscript.Pdfpage;
            page.scale = zoom_level;
            page.queue_resize ();
            overlay = overlay.get_next_sibling () as Gtk.Overlay;
        }
        scroll.get_hadjustment ().set_value (center_x * factor + h - center_x);
        scroll.get_vadjustment ().set_value (center_y * factor + v - center_y);
    }

    public bool scroll_cb (double dx, double dy) {
        var state = scroll_controller.get_current_event ()
             .get_modifier_state ();
        var ctrl = (bool) (state & Gdk.ModifierType.CONTROL_MASK);
        var scale = dy > 0 ? 1.05 : 0.95;
        if (ctrl) zoom (scale, 0, 0);
        return ctrl;
    }

    public void add_synctex_rectangle (SynctexResult res) {
        var overlay = get_first_child () as Gtk.Overlay;
        for (int i = 0; i < res.page; i++) {
            overlay = (Gtk.Overlay) overlay.get_next_sibling ();
        }
        var rect = new Manuscript.SynctexRectangle (res, zoom_level);
        overlay.add_overlay (rect);
    }

    public void scroll_to (int p, float y) {
        var overlay = get_first_child () as Gtk.Overlay;
        for (int i = 0; i < p; i++) {
            overlay = (Gtk.Overlay) overlay.get_next_sibling ();
        }
        Graphene.Point point;
        var overlay_point = Graphene.Point () { x = 0, y = y };
        overlay.compute_point (this, overlay_point, out point);
        var scroll = get_ancestor (typeof(Gtk.ScrolledWindow)) as Gtk.ScrolledWindow;
        scroll.get_vadjustment ()
              .set_value (point.y - scroll.get_height () * 0.3);
    }

    protected override void dispose () {
        remove_children();
        base.dispose ();
    }
}


private class Manuscript.Pdfpage : Gtk.Widget {

    private Poppler.Page page { get; set; }
    public double scale { get; set; }

    public Pdfpage (Poppler.Page page) {
        this.page = page;
    }

    construct {
        scale = 1.4;
    }

    protected override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.CONSTANT_SIZE;
    }

    protected override void measure (Gtk.Orientation orientation,
                                     int for_size,
                                     out int minimum,
                                     out int natural,
                                     out int minimum_baseline,
                                     out int natural_baseline) {
        minimum_baseline = -1;
        natural_baseline = -1;
        double w, h;
        page.get_size (out w, out h);
        if (orientation == Gtk.Orientation.HORIZONTAL) {
            minimum = (int) (w * scale);
            natural = (int) (w * scale);
        } else {
            minimum = (int) (h * scale);
            natural = (int) (h * scale);
        }
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        Gdk.RGBA color = { 1.0f, 1.0f, 1.0f, 1.0f };
        double w, h;
        page.get_size (out w, out h);
        var rect = Graphene.Rect ();
        rect.init (0, 0, (int) (w * scale), (int) (h * scale));
        snapshot.append_color (color, rect);
        var ctx = snapshot.append_cairo (rect);
        ctx.scale (scale, scale);
        page.render (ctx);
    }
}

private class Manuscript.SynctexRectangle : Gtk.Widget {

    private Gdk.RGBA color = Gdk.RGBA ();
    private int width;
    private int height;

    public SynctexRectangle (SynctexResult res, double scale) {
        var h = res.height+ 2;
        color.parse ("#FFF38060");
        set_halign (Gtk.Align.START);
        set_valign (Gtk.Align.START);
        set_margin_top ((int) ((res.y - h + 1) * scale));
        set_margin_start ((int) (res.x * scale));
        width = (int) (res.width * scale);
        height = (int) (res.height * scale);

        Timeout.add (700, () => {
            unparent();
            destroy ();
            return false;
        });
    }

    protected override void measure (Gtk.Orientation orientation,
                                     int for_size,
                                     out int minimum,
                                     out int natural,
                                     out int minimum_baseline,
                                     out int natural_baseline) {
        minimum_baseline = -1;
        natural_baseline = -1;
        if (orientation == Gtk.Orientation.HORIZONTAL) {
            minimum = width;
            natural = width;
        } else {
            minimum = height;
            natural = height;
        }
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        var rect = Graphene.Rect ();
        rect.init (0, 0, width, height);
        snapshot.append_color (color, rect);
    }
}
