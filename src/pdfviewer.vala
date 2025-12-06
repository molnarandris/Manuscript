[GtkTemplate (ui = "/com/github/molnarandris/latexeditor/pdfviewer.ui")]
public class Latexeditor.Pdfviewer : Gtk.Widget {

    public Pdfviewer () {
    }

    construct {
        var layout_manager = new Gtk.BinLayout ();
        this.set_layout_manager (layout_manager);
    }
}
