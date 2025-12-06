[GtkTemplate (ui = "/com/github/molnarandris/latexeditor/pdfviewer.ui")]
public class Latexeditor.Pdfviewer : Gtk.Widget {
    [GtkChild]
    private unowned Gtk.Box box;

    public Pdfviewer () {
    }

    construct {
        var layout_manager = new Gtk.BinLayout ();
        this.set_layout_manager (layout_manager);
    }
}
