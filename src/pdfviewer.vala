[GtkTemplate (ui = "/com/github/molnarandris/latexeditor/pdfviewer.ui")]
public class Latexeditor.Pdfviewer : Gtk.Widget {
    [GtkChild]
    private unowned Gtk.Box box;

    construct {
        var layout_manager = new Gtk.BinLayout ();
        this.set_layout_manager (layout_manager);

    }

    public void set_file (string uri) {
        try {
            var doc = new Poppler.Document.from_file (uri, null);
        } catch (Error e) {
            stderr.printf ("Can't open the pdf: %s: %s", uri, e.message);
        }
    }
}
