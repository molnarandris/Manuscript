[GtkTemplate (ui = "/com/github/molnarandris/manuscript/right-pane.ui")]
public class Manuscript.RightPane : Adw.Bin {
    [GtkChild]
    private unowned Manuscript.PdfViewer pdf_viewer;
    [GtkChild]
    private unowned Adw.ViewStack stack;
    [GtkChild]
    private unowned Gtk.ListBox error_list;

    public signal void error_activated(LogEntry entry);

    construct {
    }

    public void set_path (string path) {
        try{
            pdf_viewer.set_path(path);
        } catch (Error e) {
            stack.set_visible_child_name ("empty");
        }
        stack.set_visible_child_name ("pdf");
    }

    public void remove_log_entries () {
        error_list.remove_all ();
    }

    public void set_error (LogEntry[] log_entries) {
        stack.set_visible_child_name ("error");
        foreach (var entry in log_entries) {
            if (entry.type == LogType.ERROR) {
                message(entry.message);
                var row = new Adw.ActionRow();
                row.add_css_class ("error");
                row.set_title (entry.message);
                row.set_subtitle (entry.location.hint);
                var icon = new Gtk.Image.from_icon_name("error-correct-symbolic");
                row.add_suffix(icon);
                error_list.append (row);
                row.set_activatable (true);
                row.activated.connect( (r)=> {
                    error_activated(entry);
                });
            }
        }
    }

    public void add_synctex_rectangle (SynctexResult res) {
        stack.set_visible_child_name ("pdf");
        pdf_viewer.add_synctex_rectangle (res);
    }

    public void scroll_to (int page, float y) {
        stack.set_visible_child_name ("pdf");
        pdf_viewer.scroll_to (page, y);
    }
}


