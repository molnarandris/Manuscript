[GtkTemplate (ui = "/com/github/molnarandris/latexeditor/pdfviewer.ui")]
public class Latexeditor.Pdfviewer : Gtk.Widget {
    [GtkChild]
    private unowned Gtk.Box box;
    [GtkChild]
    private unowned Adw.ViewStack stack;
    [GtkChild]
    private unowned Gtk.ScrolledWindow scroll;

    private double scale = 1.4;
    private double zoom_tmp = 1;
    private double hadj = 0;
    private double vadj = 0;

    construct {
        var layout_manager = new Gtk.BinLayout ();
        this.set_layout_manager (layout_manager);
        var controller = new Gtk.GestureZoom ();
        controller.begin.connect(this.on_zoom_start);
        controller.end.connect(this.on_zoom_end);
        controller.scale_changed.connect(this.on_zoom_change);
        this.add_controller (controller);
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
            this.box.append(page);
        }
        this.stack.set_visible_child_name("pdf");
    }

    public void set_error() {
        this.remove_children ();
        this.stack.set_visible_child_name ("error");
    }

    public void on_zoom_start (Gdk.EventSequence? sequence) {
        this.hadj = this.scroll.get_hadjustment ().get_value ();
        this.vadj = this.scroll.get_vadjustment ().get_value ();
    }

    public void on_zoom_end (Gdk.EventSequence? sequence) {
        this.scale *= this.zoom_tmp;
        this.hadj = this.scroll.get_hadjustment ().get_value ();
        this.vadj = this.scroll.get_vadjustment ().get_value ();
    }

    public void on_zoom_change (double scale) {
        this.zoom_tmp = scale;
        var child = box.get_first_child () as Latexeditor.Pdfpage;
        while (child!=null) {
            child.scale = this.scale*scale;
            child.queue_resize ();
            child.queue_draw ();
            child = child.get_next_sibling () as Latexeditor.Pdfpage;
        }
        this.scroll.get_hadjustment ().set_value (this.hadj*scale);
        this.scroll.get_vadjustment ().set_value (this.vadj*scale);
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
