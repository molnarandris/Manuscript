[GtkTemplate (ui = "/com/github/molnarandris/manuscript/pdfpane.ui")]
public class Manuscript.PdfPane : Adw.Bin {
    [GtkChild]
    private unowned Manuscript.PdfViewer pdf_viewer;
    [GtkChild]
    private unowned Adw.ViewStack stack;
    [GtkChild]
    private unowned Gtk.ListBox error_list;

    public signal void error_activated(LogEntry entry);
    public signal void synctex_back (SourceLocation? location);

    construct {
        pdf_viewer.synctex_back.connect (on_synctex_backwards);
    }

    public void set_path (string path) {
        try {
            pdf_viewer.set_path (path);
            stack.set_visible_child_name ("pdf");
        } catch (Error e) {
            stack.set_visible_child_name ("empty");
        }
    }

    public void remove_log_entries () {
        error_list.remove_all ();
    }

    public void set_error (LogEntry[] log_entries) {
        stack.set_visible_child_name ("error");
        foreach (var entry in log_entries) {
            if (entry.type == LogType.ERROR) {
                message (entry.message);
                var row = new Adw.ActionRow ();
                row.add_css_class ("error");
                row.set_title (entry.message);
                row.set_subtitle (entry.location.hint);
                var icon = new Gtk.Image.from_icon_name ("error-correct-symbolic");
                row.add_suffix (icon);
                error_list.append (row);
                row.set_activatable (true);
                row.activated.connect ((r) => {
                    error_activated (entry);
                });
            }
        }
    }

    public void add_synctex_rectangles (Gee.HashMap<int, Gee.ArrayList<Graphene.Rect?>> synctex_results) {
        stack.set_visible_child_name ("pdf");
        pdf_viewer.add_synctex_rectangles (synctex_results);
    }

    public void on_synctex_backwards (string path, int page, double x, double y) {
        var position = string.join (":", (page + 1).to_string (), x.to_string (), y.to_string (), path);
        run_synctex.begin (position, (obj, res) => {
            try {
                var location = run_synctex.end (res);
                this.synctex_back.emit (location);
            } catch (Error e) {
                warning ("Synctex callback error: %s", e.message);
            }
        });
    }

    public async SourceLocation? run_synctex (string position) throws Error {
        Subprocess proc;
        try {
            // watch-bus required to cancel
            proc = new Subprocess (SubprocessFlags.SEARCH_PATH_FROM_ENVP|
                                   SubprocessFlags.STDOUT_PIPE|
                                   SubprocessFlags.STDERR_PIPE,
                                   "flatpak-spawn", "--host", "--watch-bus",
                                   "synctex", "edit",
                                   "-o", position);
        } catch (Error e) {
            stderr.printf ("Synctex spawn error: %s\n", e.message);
            throw e;
        }

        string stdout, stderr;
        try {
            yield proc.communicate_utf8_async (null, null, out stdout, out stderr);
        } catch (Error e) {
            message ("Synctex failed: %s", e.message);
            throw e;
        }

        return parse_synctex_result (stdout);
    }

    private SourceLocation? parse_synctex_result (string result_string) {
        try {
            var regex = new Regex ("^Line:(\\d+)$", RegexCompileFlags.MULTILINE);

            MatchInfo match;
            if (!regex.match (result_string, 0, out match)) {
                return null;
            }

            var location = SourceLocation ();
            location.line = int.parse (match.fetch (1));

            return location;
        } catch (Error e) {
            warning ("Synctex parse error: %s", e.message);
            return null;
        }
    }

}


