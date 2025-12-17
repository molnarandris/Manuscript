[GtkTemplate (ui = "/com/github/molnarandris/latexeditor/pdfviewer.ui")]
public class Latexeditor.Pdfviewer : Gtk.Widget {
    [GtkChild]
    private unowned Gtk.Box box;
    [GtkChild]
    private unowned Adw.ViewStack stack;
    [GtkChild]
    private unowned Gtk.ScrolledWindow scroll;

    private double prev_zoom_gesture_scale = 1;
    private double zoom_level = 1.4;

    private Gtk.EventControllerScroll scroll_controller;

    construct {
        var layout_manager = new Gtk.BinLayout ();
        this.set_layout_manager (layout_manager);
        var controller = new Gtk.GestureZoom ();
        controller.begin.connect(this.zoom_gesture_begin_cb);
        controller.scale_changed.connect(this.zoom_gesture_scale_changed_cb);
        this.add_controller (controller);

        scroll_controller = new Gtk.EventControllerScroll (Gtk.EventControllerScrollFlags.VERTICAL);
        scroll_controller.scroll.connect(this.scroll_cb);
        this.scroll.add_controller (scroll_controller);
    }

    private void remove_children () {
        Gtk.Widget? child = null;
        child = box.get_first_child () as Gtk.Widget;
        while (child!=null) {
            box.remove(child);
            child = box.get_first_child () as Gtk.Widget;
        }
    }

    public void set_file (string uri) {
        this.remove_children ();

        Poppler.Document doc;
        try {
            doc = new Poppler.Document.from_file (uri, null);
        } catch (Error e) {
            stderr.printf ("Can't open the pdf: %s: %s", uri, e.message);
            stack.set_visible_child_name("empty");
            return;
        }

        for (int i =0; i< doc.get_n_pages(); i++) {
            var page = new Latexeditor.Pdfpage (doc.get_page (i));
            var overlay = new Gtk.Overlay ();
            overlay.set_child(page);
            this.box.append(overlay);
        }
        this.stack.set_visible_child_name("pdf");
    }

    public void set_error() {
        this.remove_children ();
        this.stack.set_visible_child_name ("error");
    }

    public void zoom_gesture_begin_cb (Gdk.EventSequence? sequence) {
        prev_zoom_gesture_scale = 1;
    }

    public void zoom_gesture_scale_changed_cb (double scale) {
        var factor = scale - prev_zoom_gesture_scale + 1;
        this.zoom(factor, 0, 0);
        prev_zoom_gesture_scale = scale;
    }

    /**
     * Zooms around a given coordinate.
     *
     * @factor: zoom factor to apply
     * @x: x coordinate to zoom around
     * @y: y coordinate to zoom around
     */
    public void zoom (double factor, double x, double y) {
        this.zoom_level*=factor;
        var h = scroll.get_hadjustment ().get_value ();
        var v = scroll.get_vadjustment ().get_value ();
        var overlay = box.get_first_child () as Gtk.Overlay;
        while (overlay!=null) {
            var page = overlay.get_child() as Latexeditor.Pdfpage;
            page.scale = this.zoom_level;
            page.queue_resize ();
            page.queue_draw ();
            overlay = overlay.get_next_sibling () as Gtk.Overlay;
        }
        this.scroll.get_hadjustment ().set_value (h*factor);
        this.scroll.get_vadjustment ().set_value (v*factor);
    }

    public bool scroll_cb (double dx, double dy) {
        var state = scroll_controller.get_current_event ()
                                     .get_modifier_state ();
        var ctrl = (bool) (state & Gdk.ModifierType.CONTROL_MASK);
        var scale = dy>0 ? 1.05: 0.95;
        if (ctrl) this.zoom (scale, 0, 0);
        return ctrl;
    }

    public void add_synctex_rectangle(int p, float x, float y, float w, float h) {
        var overlay = this.box.get_first_child () as Gtk.Overlay;
        for (int i=0; i<p; i++) {
            overlay = (Gtk.Overlay) overlay.get_next_sibling ();
        }
        var rect = new Latexeditor.SynctexRectangle(x,y,w,h,this.zoom_level);
        overlay.add_overlay(rect);
    }

    public void scroll_to(int p, float y) {
        var overlay = this.box.get_first_child () as Gtk.Overlay;
        for (int i=0; i<p; i++) {
            overlay = (Gtk.Overlay) overlay.get_next_sibling ();
        }
        Graphene.Point box_point;
        var overlay_point = Graphene.Point () {x = 0, y = y};
        overlay.compute_point (box, overlay_point, out box_point);
        scroll.get_vadjustment ()
              .set_value (box_point.y - scroll.get_height()*0.3);
    }
}

private class Latexeditor.Pdfpage : Gtk.Widget {

    private Poppler.Page page { get; set; }
    public double scale { get; set; }

    public Pdfpage (Poppler.Page page) {
        this.page = page;

    }

    construct {
        scale = 1.4;
    }

    protected override Gtk.SizeRequestMode get_request_mode() {
        return Gtk.SizeRequestMode.CONSTANT_SIZE;
    }

    protected override void measure (Gtk.Orientation orientation,
                                     int for_size,
                                     out int minimum,
                                     out int natural,
                                     out int minimum_baseline,
                                     out int natural_baseline)  {
        minimum_baseline = -1;
        natural_baseline = -1;
        double w, h;
        page.get_size (out w, out h);
        if (orientation == Gtk.Orientation.HORIZONTAL) {
            minimum = (int) (w*scale);
            natural = (int) (w*scale);
        } else {
            minimum = (int) (h*scale);
            natural = (int) (h*scale);
        }
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        Gdk.RGBA color =  { 1.0f, 1.0f, 1.0f, 1.0f };
        double w, h;
        page.get_size (out w, out h);
        var rect = Graphene.Rect ();
        rect.init(0, 0, (int) (w*scale), (int) (h*scale));
        snapshot.append_color (color, rect);
        var ctx = snapshot.append_cairo (rect);
        ctx.scale(scale, scale);
        page.render(ctx);
    }
}

private class Latexeditor.SynctexRectangle : Gtk.Widget {

    private Gdk.RGBA color = Gdk.RGBA ();
    private int width;
    private int height;

    public SynctexRectangle (float x, float y, float w, float h, double scale) {
        h += 2;
        this.color.parse("#FFF38060");
        this.set_halign (Gtk.Align.START);
        this.set_valign (Gtk.Align.START);
        this.set_margin_top((int) ((y-h+1)*scale));
        this.set_margin_start((int) (x*scale));
        this.width = (int) (w*scale);
        this.height = (int) (h*scale);

        Timeout.add (700, () => {
            this.unparent ();
            this.destroy ();
            return false;
        });
    }

    protected override void measure (Gtk.Orientation orientation,
                                     int for_size,
                                     out int minimum,
                                     out int natural,
                                     out int minimum_baseline,
                                     out int natural_baseline)  {
        minimum_baseline = -1;
        natural_baseline = -1;
        if (orientation == Gtk.Orientation.HORIZONTAL) {
            minimum = this.width;
            natural = this.width;
        } else {
            minimum = this.height;
            natural = this.height;
        }
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        var rect = Graphene.Rect();
        rect.init(0, 0, this.width, this.height);
        snapshot.append_color(this.color, rect);
    }
}
