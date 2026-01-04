[GtkTemplate (ui = "/com/github/molnarandris/manuscript/editor.ui")]
public class Manuscript.Editor : Adw.Bin {
    [GtkChild]
    private unowned GtkSource.View source_view;

    public string? basename {get; private set; default = null;}
    public string? dir {get; private set; default = null;}
    public string? path {get; private set; default = null;}
    public bool modified {get; private set; default = false;}
    private File? _file = null;
    public File? file {
        get { return _file; }
        private set {
            _file = value;
            if (_file == null) {
                basename = null;
                dir = null;
                path = null;
            } else {
                basename = _file.get_basename();
                dir = _file.get_parent().get_path();
                path = _file.get_path();
            }
        }
    }
    private Gtk.FileDialog file_dialog = new Gtk.FileDialog ();
    private GtkSource.Buffer buffer;

    construct {
        buffer = source_view.buffer as GtkSource.Buffer;

        var lm = new GtkSource.LanguageManager();
        var latex = lm.get_language ("mylatex");
        buffer.set_language (latex);

        var sm = new GtkSource.StyleSchemeManager();
        var style = sm.get_scheme("manuscript-classic");
        buffer.set_style_scheme(style);

        var provider = new Manuscript.CompletionProvider ();
        var completion = this.source_view.get_completion ();
        completion.set_property ("select-on-show", true);
        completion.add_provider(provider);

        var filters = new ListStore ( typeof(Gtk.FileFilter) );

        var latex_filter = new Gtk.FileFilter();
        latex_filter.add_mime_type ("text/x-tex");
        filters.append (latex_filter);

        var text_filter = new Gtk.FileFilter();
        text_filter.add_mime_type ("text/plain");
        filters.append (text_filter);

        file_dialog.set_filters (filters);
        file_dialog.set_default_filter (latex_filter);

        buffer.modified_changed.connect(() => {
            modified = buffer.get_modified();
        });
    }

    public void goto_log_entry(LogEntry entry) {
        Gtk.TextIter iter;
        buffer.get_iter_at_line (out iter, entry.location.line - 1);
        source_view.scroll_to_iter (iter, 0.3, false, 0, 0);
        buffer.place_cursor(iter);
        source_view.grab_focus ();
    }

    public SourceLocation get_cursor_location() {
        Gtk.TextIter iter;
        buffer.get_iter_at_mark (out iter, buffer.get_insert ());

        return SourceLocation () {
            file   = file.peek_path (),
            line   = iter.get_line (),
            offset = iter.get_line_offset (),
            hint   = null
        };
    }

    public async void open_file_with_dialog () {
        assert(root != null);

        File? file;
        try {
            file = yield file_dialog.open(root as Gtk.Window, null);
        } catch (Error e) {
            stderr.printf ("Unable to select file: %s", e.message);
            return;
        }
        yield open_file (file);
    }

    public async void open_file (File file) {
        string display_name = get_display_name (file);
        uint8[] contents;
        try {
            yield file.load_contents_async (null, out contents, null);
        } catch (Error e) {
            stderr.printf ("Unable to open “%s“: %s", display_name, e.message);
        }

        if (!((string) contents).validate ()) {
            stderr.printf ("Unable to load the contents of “%s”: "+
                           "the file is not encoded with UTF-8\n",
                           display_name);
            return;
        }

        set_text((string) contents);
        this.file = file;
    }

    private void set_text(string contents) {
        buffer.text = contents;
        Gtk.TextIter start;
        buffer.get_start_iter (out start);
        buffer.place_cursor (start);
        buffer.set_modified (false);
    }

    public async void save_file_with_dialog () {
        assert(root != null);

        File? file = null;
        try {
            file = yield file_dialog.save((Gtk.Window) root, null);
        } catch (Error e) {
            stderr.printf ("Unable to select file: %s", e.message);
            return;
        }
        yield save_file (file);
    }

    public async void save_file (File file) {
        var text = get_text ();
        var bytes = new Bytes.take (text.data);

        try{
            yield file.replace_contents_bytes_async (bytes, null, false, FileCreateFlags.NONE, null, null);
        } catch (Error e) {
            var display_name = get_display_name (file);
            stderr.printf ("Unable to save “%s”: %s\n", display_name, e.message);
            return;
        }

        this.file = file;
        buffer.set_modified (false);
    }

    private string get_text() {
        Gtk.TextIter start, end;

        buffer.get_start_iter (out start);
        buffer.get_end_iter (out end);

        return buffer.get_text (start, end, false);
    }

    private string get_display_name(File? file) {
        string display_name;
        if (file == null) {
            return "New Document";
        }
        try {
            FileInfo info = file.query_info ("standard::display-name", FileQueryInfoFlags.NONE);
            display_name = info.get_attribute_string ("standard::display-name");
        } catch (Error e) {
            display_name = file.get_basename ();
        }
        return display_name;
    }
}

