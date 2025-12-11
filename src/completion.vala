public class Latexeditor.CompletionProvider: Object, GtkSource.CompletionProvider {

    public CompletionProvider () {
        Object();
    }

    construct {
    }


    public void activate (GtkSource.CompletionContext context,
                          GtkSource.CompletionProposal proposal) {
        var buffer = context.get_buffer ();
        Gtk.TextIter begin, end;
        context.get_bounds (out begin, out end);
        buffer.insert (ref end, "Hello world", -1);
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
        var store = new ListStore(typeof (CommandCompletionProposal));
        store.append( new CommandCompletionProposal ("Hello world"));
        return store;
    }

    public void refilter (GtkSource.CompletionContext context,
                          ListModel model) {
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
