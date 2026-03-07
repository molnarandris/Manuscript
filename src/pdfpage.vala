private class Manuscript.Pdfpage : Gtk.Widget {

    private Poppler.Page page { get; set; }
    public double scale { get; set; }
    public int index {
        get {
            return page.get_index ();
        }
    }
    public Gee.ArrayList<Graphene.Rect?> synctex_rectangles = new Gee.ArrayList<Graphene.Rect?> ();

    public signal void synctex_back (int p, double x, double y);

    public Pdfpage (Poppler.Page page) {
        this.page = page;
    }

    construct {
        scale = 1.4;
        var click_controller = new Gtk.GestureClick ();
        this.add_controller (click_controller);
        click_controller.pressed.connect (on_click);
    }

    private void on_click(int n_press, double x, double y){
        if (n_press!=2) return;
        this.synctex_back.emit(index, x/scale, y/scale);
    }

    protected override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.CONSTANT_SIZE;
    }

    protected override void measure (Gtk.Orientation orientation, int for_size,
                                     out int minimum, out int natural,
                                     out int minimum_baseline, out int natural_baseline) {
        minimum_baseline = natural_baseline = -1;
        double w, h;
        page.get_size (out w, out h);
        if (orientation == Gtk.Orientation.HORIZONTAL) {
            minimum = natural = (int) (w * scale);
        } else {
            minimum = natural = (int) (h * scale);
        }
    }

    public void add_synctex_rectangles (Gee.ArrayList<Graphene.Rect?> rectangles) {
        if (synctex_rectangles.size !=0) return;
        foreach(var rect in rectangles) {
            synctex_rectangles.add (rect);
        }
        queue_draw ();

        GLib.Timeout.add (700, () => {
            synctex_rectangles.clear();
            queue_draw ();
            return false;
        });
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        Gdk.RGBA white = { 1.0f, 1.0f, 1.0f, 1.0f };
        double w, h;
        page.get_size (out w, out h);
        var page_rectangle = Graphene.Rect ();
        page_rectangle.init (0, 0, (int) (w * scale), (int) (h * scale));
        snapshot.append_color (white, page_rectangle);
        foreach (var synctex_rectangle in synctex_rectangles) {
            var yellow = Gdk.RGBA () { red = 1.0f, green = 1.0f, blue = 0.0f, alpha = 0.4f };
            synctex_rectangle = synctex_rectangle.scale ( (float) scale, (float)  scale);
            snapshot.append_color (yellow, synctex_rectangle);
        }
        var ctx = snapshot.append_cairo (page_rectangle);
        ctx.scale (scale, scale);
        page.render (ctx);
    }
}
