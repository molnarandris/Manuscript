[GtkTemplate (ui = "/com/github/molnarandris/manuscript/editor.ui")]
public class Manuscript.Editor : Adw.Bin {
    [GtkChild]
    private unowned GtkSource.View source_view;
    [GtkChild]
    private unowned Adw.Banner banner;

    public bool modified {get; private set; default = false;}
    public LatexFile? file {get; set; default = null;}
    private Gtk.FileDialog file_dialog = new Gtk.FileDialog ();
    private GtkSource.Buffer buffer;

    private Gee.HashMap<string,string> latex_to_unicode;
    private Gee.HashMap<string,string> unicode_to_latex;

    bool internal_edit = false; // prevent recursion


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
        buffer.insert_text.connect(on_insert_text);

        banner.button_clicked.connect (on_banner_button_clicked);

        latex_to_unicode = new Gee.HashMap<string,string> ();

        latex_to_unicode["\\alpha"]   = "α";
        latex_to_unicode["\\beta"]    = "β";
        latex_to_unicode["\\gamma"]   = "γ";
        latex_to_unicode["\\delta"]   = "δ";
        latex_to_unicode["\\epsilon"] = "ε";
        latex_to_unicode["\\zeta"]    = "ζ";
        latex_to_unicode["\\eta"]     = "η";
        latex_to_unicode["\\theta"]   = "θ";
        latex_to_unicode["\\iota"]    = "ι";
        latex_to_unicode["\\kappa"]   = "κ";
        latex_to_unicode["\\lambda"]  = "λ";
        latex_to_unicode["\\mu"]      = "μ";
        latex_to_unicode["\\nu"]      = "ν";
        latex_to_unicode["\\xi"]      = "ξ";
        latex_to_unicode["\\omicron"] = "ο";
        latex_to_unicode["\\pi"]      = "π";
        latex_to_unicode["\\rho"]     = "ρ";
        latex_to_unicode["\\sigma"]   = "σ";
        latex_to_unicode["\\tau"]     = "τ";
        latex_to_unicode["\\upsilon"] = "υ";
        latex_to_unicode["\\phi"]     = "φ";
        latex_to_unicode["\\chi"]     = "χ";
        latex_to_unicode["\\psi"]     = "ψ";
        latex_to_unicode["\\omega"]   = "ω";

        // uppercase
        latex_to_unicode["\\Gamma"]   = "Γ";
        latex_to_unicode["\\Delta"]   = "Δ";
        latex_to_unicode["\\Theta"]   = "Θ";
        latex_to_unicode["\\Lambda"]  = "Λ";
        latex_to_unicode["\\Xi"]      = "Ξ";
        latex_to_unicode["\\Pi"]      = "Π";
        latex_to_unicode["\\Sigma"]   = "Σ";
        latex_to_unicode["\\Upsilon"] = "Υ";
        latex_to_unicode["\\Phi"]     = "Φ";
        latex_to_unicode["\\Psi"]     = "Ψ";
        latex_to_unicode["\\Omega"]   = "Ω";

        // calligraphic uppercase
        latex_to_unicode["\\mathcal{A}"] = "𝒜"; // U+1D49C
        latex_to_unicode["\\mathcal{B}"] = "ℬ"; // U+212C (standard)
        latex_to_unicode["\\mathcal{C}"] = "𝒞"; // U+1D49E
        latex_to_unicode["\\mathcal{D}"] = "𝒟"; // U+1D49F
        latex_to_unicode["\\mathcal{E}"] = "ℰ"; // U+2130
        latex_to_unicode["\\mathcal{F}"] = "ℱ"; // U+2131
        latex_to_unicode["\\mathcal{G}"] = "𝒢"; // U+1D4A2
        latex_to_unicode["\\mathcal{H}"] = "ℋ"; // U+210B
        latex_to_unicode["\\mathcal{I}"] = "ℐ"; // U+2110
        latex_to_unicode["\\mathcal{J}"] = "𝒥"; // U+1D4A5
        latex_to_unicode["\\mathcal{K}"] = "𝒦"; // U+1D4A6
        latex_to_unicode["\\mathcal{L}"] = "ℒ"; // U+2112
        latex_to_unicode["\\mathcal{M}"] = "ℳ"; // U+2133
        latex_to_unicode["\\mathcal{N}"] = "𝒩"; // U+1D4AB
        latex_to_unicode["\\mathcal{O}"] = "𝒪"; // U+1D4AC
        latex_to_unicode["\\mathcal{P}"] = "𝒫"; // U+1D4AD
        latex_to_unicode["\\mathcal{Q}"] = "𝒬"; // U+1D4AE
        latex_to_unicode["\\mathcal{R}"] = "ℛ"; // U+211B
        latex_to_unicode["\\mathcal{S}"] = "𝒮"; // U+1D4B0
        latex_to_unicode["\\mathcal{T}"] = "𝒯"; // U+1D4B1
        latex_to_unicode["\\mathcal{U}"] = "𝒰"; // U+1D4B2
        latex_to_unicode["\\mathcal{V}"] = "𝒱"; // U+1D4B3
        latex_to_unicode["\\mathcal{W}"] = "𝒲"; // U+1D4B4
        latex_to_unicode["\\mathcal{X}"] = "𝒳"; // U+1D4B5
        latex_to_unicode["\\mathcal{Y}"] = "𝒴"; // U+1D4B6
        latex_to_unicode["\\mathcal{Z}"] = "𝒵"; // U+1D4B7

        // blackboard-bold (mathbb) -- only the commonly defined Unicode symbols
        latex_to_unicode["\\mathbb{C}"] = "ℂ";
        latex_to_unicode["\\mathbb{H}"] = "ℍ";
        latex_to_unicode["\\mathbb{N}"] = "ℕ";
        latex_to_unicode["\\mathbb{P}"] = "ℙ";
        latex_to_unicode["\\mathbb{Q}"] = "ℚ";
        latex_to_unicode["\\mathbb{R}"] = "ℝ";
        latex_to_unicode["\\mathbb{Z}"] = "ℤ";

        // common math symbols
        latex_to_unicode["\\in"]      = "∈";  // U+2208
        latex_to_unicode["\\notin"]   = "∉";  // U+2209
        latex_to_unicode["\\cdot"]    = "⋅";  // U+22C5
        latex_to_unicode["\\mapsto"]  = "↦";  // U+21A6
        latex_to_unicode["\\to"]      = "→";  // U+2192
        latex_to_unicode["\\rightarrow"] = "→"; // alternative to \to
        latex_to_unicode["\\Rightarrow"] = "⇒"; // U+21D2
        latex_to_unicode["\\leftarrow"]  = "←"; // U+2190
        latex_to_unicode["\\Leftarrow"]  = "⇐"; // U+21D0
        latex_to_unicode["\\otimes"] = "⊗";
        latex_to_unicode["\\oplus"]   = "⊕";
        latex_to_unicode["\\boxtimes"]   = "⊠";
        latex_to_unicode["\\circ"] = "∘";
        latex_to_unicode["\\subset"] = "⊂";
        latex_to_unicode["\\subseteq"] = "⊆";
        latex_to_unicode["\\cap"] = "∩";
        latex_to_unicode["\\cup"] = "∪";
        latex_to_unicode["\\simeq"] = "≈";
        latex_to_unicode["\\partial"] = "∂";
        latex_to_unicode["\\forall"] = "∀";
        latex_to_unicode["\\exists"] = "∃";
        latex_to_unicode["\\emptyset"] = "∅";




        unicode_to_latex = new Gee.HashMap<string,string>();
        foreach (var k in latex_to_unicode.keys)
            unicode_to_latex[latex_to_unicode[k]] = k;
    }


    private void on_insert_text (Gtk.TextBuffer buffer,
                                 Gtk.TextIter location,
                                 string text,
                                 int length)
    {
        if (internal_edit)
            return;

        internal_edit = true;

        // Iterate over all LaTeX → Unicode mappings
        foreach (var k in latex_to_unicode.keys) {
            int len = k.length;
            Gtk.TextIter start = location;

            // Move start back by length of LaTeX command
            if (!start.backward_chars(len))
                continue;

            string recent = buffer.get_text(start, location, false);

            if (recent == k) {
                // Replace LaTeX with Unicode
                buffer.delete(ref start, ref location);
                buffer.insert(ref start, latex_to_unicode[k], -1);

                // Adjust location for next iterations
                break; // only replace one match at a time
            }
        }

        internal_edit = false;
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
            file   = file.path,
            line   = iter.get_line (),
            offset = iter.get_line_offset (),
            hint   = null
        };
    }

    public async void open_file_with_dialog () throws Error {
        assert(root != null);

        File? file_to_open;
        try {
            file_to_open = yield file_dialog.open(root as Gtk.Window, null);
        } catch (Gtk.DialogError.DISMISSED e) {
            return;
        }
        yield open_file (new LatexFile(file_to_open));
    }

    private async void open_file (LatexFile file_to_open) throws Error {
        string contents;
        contents = yield file_to_open.load_contents ();
        set_text(contents);
        file = file_to_open;
        file.changed.connect (()=>{
            banner.revealed = true;
        });
    }

    private void on_banner_button_clicked() {
        banner.revealed = false;
        open_file.begin(file, (obj,res) => {
            try{
                open_file.end(res);
            } catch (Error e) {
                message("Error reloading file: %s", e.message);
            }
        });
    }

    private string replace_latex_by_unicode(string input) {
        string text = input;
        foreach (var k in latex_to_unicode.keys) {
            text = text.replace(k, latex_to_unicode[k]);
        }
        return text;
    }

    private void set_text(string contents) {
        buffer.text = replace_latex_by_unicode(contents);
        Gtk.TextIter start;
        buffer.get_start_iter (out start);
        buffer.place_cursor (start);
        buffer.set_modified (false);
    }

    public async void save () throws Error {
        if (file == null) {
            yield save_with_dialog();
        } else {
            yield save_file(file);
        }
    }

    public async void save_with_dialog ()  throws Error {
        assert(root != null);

        File? file_to_save = null;
        try {
            file_to_save = yield file_dialog.save((Gtk.Window) root, null);
        } catch (Gtk.DialogError.DISMISSED e) {
            return;
        }

        yield save_file (new LatexFile(file_to_save));
    }

    public string normalize_buffer_for_saving(string input) {
        string text = input;
        foreach (var u in unicode_to_latex.keys) {
            text = text.replace(u, unicode_to_latex[u]);
        }
        return text;
    }

    private async void save_file (LatexFile file_to_save)  throws Error {
        var text = get_text ();
        text = normalize_buffer_for_saving(text);

        yield file_to_save.replace_contents (text);

        buffer.set_modified (false);
        file = file_to_save;
    }

    private string get_text() {
        Gtk.TextIter start, end;

        buffer.get_start_iter (out start);
        buffer.get_end_iter (out end);

        return buffer.get_text (start, end, false);
    }

    public void scroll_to (SourceLocation location) {

        int line = location.line;
        int offset = location.offset;

        Gtk.TextIter iter;
        buffer.get_iter_at_line_offset (out iter, line-1, offset);

        buffer.place_cursor (iter);
        source_view.scroll_to_iter (iter, 0.2, false, 0.0, 0.0);
        source_view.grab_focus ();
    }
}

