[GtkTemplate (ui = "/com/github/molnarandris/latexeditor/pdfviewer.ui")]
public class Latexeditor.Pdfviewer : Gtk.Widget {
    [GtkChild]
    private unowned Gtk.Box box;
    [GtkChild]
    private unowned Adw.ViewStack stack;

    construct {
        var layout_manager = new Gtk.BinLayout ();
        this.set_layout_manager (layout_manager);

    }

    public void set_file (string uri) {

        Gtk.Widget? child = null;
        child = box.get_first_child () as Gtk.Widget;
        while (child!=null) {
            box.remove(child);
            child = box.get_first_child () as Gtk.Widget;
        }

        Poppler.Document doc;
        try {
            doc = new Poppler.Document.from_file (uri, null);
        } catch (Error e) {
            stderr.printf ("Can't open the pdf: %s: %s", uri, e.message);
            stack.set_visible_child_name("empty");
            return;
        }

        for (int i =0; i< doc.get_n_pages(); i++) {
            message("%d", i);
            var page = new Latexeditor.Pdfpage ();
            this.box.append(page);
        }
        this.stack.set_visible_child_name("pdf");
    }
}

private class Latexeditor.Pdfpage : Gtk.Widget {

    construct {
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
        if (orientation == Gtk.Orientation.HORIZONTAL) {
            minimum = 20;
            natural = 20;
        } else {
            minimum = 20;
            natural = 20;
        }
    }

    protected override void snapshot (Gtk.Snapshot snapshot) {
        Gdk.RGBA color =  { 1.0f, 1.0f, 1.0f, 1.0f };
        var rect = Graphene.Rect ();
        rect.init(0, 0, 20, 20);
        snapshot.append_color (color, rect);
    }
}
