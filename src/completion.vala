public class Latexeditor.CompletionProvider: Object, GtkSource.CompletionProvider {

    Gtk.FilterListModel proposals {get; set;}

    public CompletionProvider () {
        Object();
    }

    construct {
        var store = new ListStore(typeof (CommandCompletionProposal));
        read_file("/app/share/completion/latex-document.cwl", store);
        read_file("/app/share/completion/latex-mathsymbols.cwl", store);

        var filter = new Gtk.CustomFilter (null);
        proposals = new Gtk.FilterListModel (store, filter);
    }

    private void read_file(string filename, ListStore store) {
        var file = File.new_for_path (filename);
        uint8[] contents;
        try {
            file.load_contents (null, out contents, null);
        } catch (Error e) {
            message("Can't read completion file");
        }
        var lines = ((string) contents).split ("\n");
        foreach (unowned string line in lines) {
            store.append (new CommandCompletionProposal(line));
        }
    }


    public void activate (GtkSource.CompletionContext context,
                          GtkSource.CompletionProposal proposal) {
        var buffer = context.get_buffer ();
        Gtk.TextIter begin, end;
        context.get_bounds (out begin, out end);
        begin.backward_char ();
        buffer.delete(ref begin, ref end);
        buffer.insert (ref end, proposal.get_typed_text(), -1);
    }

    public void display (GtkSource.CompletionContext context,
                         GtkSource.CompletionProposal proposal,
                         GtkSource.CompletionCell cell) {
        if (cell.column == GtkSource.CompletionColumn.TYPED_TEXT) {
            cell.set_text (proposal.get_typed_text());
        }
    }

    public async ListModel populate_async (GtkSource.CompletionContext context,
                                           Cancellable? cancellable) {
        var empty_store = new ListStore(typeof (CommandCompletionProposal));
        if (context.get_word() != "") return empty_store;
        return proposals;
    }

    public void refilter (GtkSource.CompletionContext context,
                          ListModel model) {
        var word = "\\" + context.get_word();
        var filter = proposals.get_filter () as Gtk.CustomFilter;
        filter.set_filter_func((item) => {
            return ((CommandCompletionProposal) item)
                   .get_typed_text()
                   .has_prefix(word);
        });
        filter.changed(Gtk.FilterChange.DIFFERENT);
    }

    public bool is_trigger (Gtk.TextIter iter, unichar ch) {
        return ch == '\\';
    }
}

class Latexeditor.CommandCompletionProposal: Object, GtkSource.CompletionProposal {

    public string text { get; construct; }

    public CommandCompletionProposal (string text) {
        Object(text: text);
    }

    construct {
    }

    string? get_typed_text () {
        return this.text;
    }

}
