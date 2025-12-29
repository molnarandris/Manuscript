/* window.vala
 *
 * Copyright 2025 Andras Molnar
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[GtkTemplate (ui = "/com/github/molnarandris/manuscript/window.ui")]
public class Manuscript.Window : Adw.ApplicationWindow {
    [GtkChild]
    private unowned GtkSource.View source_view;
    [GtkChild]
    private unowned Adw.WindowTitle window_title;
    [GtkChild]
    private unowned Gtk.Button compile_button;
    [GtkChild]
    private unowned Manuscript.Pdfviewer pdfviewer;

    public File? file { get; private set; default=null; }
    private Compiler compiler = new Compiler();
    private Synctex synctex_engine = new Synctex();

    public Window (Gtk.Application app) {
        Object (application: app);
    }

    private ActionEntry[] actions = {
            {"open", open_file_with_dialog},
            {"save-as", save_file_with_dialog},
            {"save", on_save_action},
            {"compile", on_compile_action},
            {"synctex", on_synctex_action},
        };

    private Gtk.FileDialog filechooser = new Gtk.FileDialog ();

    construct {
        add_action_entries (actions, this);

        var lm = new GtkSource.LanguageManager();
        var latex = lm.get_language ("mylatex");
        var buffer = source_view.get_buffer () as GtkSource.Buffer;
        buffer.set_language (latex);

        var sm = new GtkSource.StyleSchemeManager();
        var style = sm.get_scheme("manuscript-classic");
        buffer.set_style_scheme(style);

        var provider = new Manuscript.CompletionProvider ();
        var completion = this.source_view.get_completion ();
        completion.set_property ("select-on-show", true);
        completion.add_provider(provider);

        buffer.modified_changed.connect (() => {
            var modified = buffer.get_modified ();
            string title = this.get_display_name (this.file);
            if (modified) {
                title = "• " + title;
            }
            this.window_title.set_title(title);
        });

        var filters = new ListStore ( typeof(Gtk.FileFilter) );

        var latex_filter = new Gtk.FileFilter();
        latex_filter.add_mime_type ("text/x-tex");
        filters.append (latex_filter);

        var text_filter = new Gtk.FileFilter();
        text_filter.add_mime_type ("text/plain");
        filters.append (text_filter);

        this.filechooser.set_filters (filters);
        this.filechooser.set_default_filter (latex_filter);

        pdfviewer.error_activated.connect (goto_log_entry);
    }

    private void open_file_with_dialog () {
        this.filechooser.open.begin (this, null, (object, result) => {
            File? file = null;
            try {
                file = filechooser.open.end(result);
            } catch (Error e) {
                stderr.printf ("Unable to select file: %s", e.message);
                return;
            }
            this.open_file (file);
        });
    }

    private void open_file (File file) {
        file.load_contents_async.begin (null, (object, result) => {
            string display_name = this.get_display_name (file);
            uint8[] contents;
            try {
                file.load_contents_async.end (result, out contents, null);
            } catch (Error e) {
                stderr.printf ("Unable to open “%s“: %s", file.peek_path (), e.message);
            }

            if (!((string) contents).validate ()) {
                stderr.printf ("Unable to load the contents of “%s”: "+
                               "the file is not encoded with UTF-8\n",
                               file.peek_path ());
                return;
            }

            GtkSource.Buffer buffer = this.source_view.buffer as GtkSource.Buffer;
            buffer.text = (string) contents;
            Gtk.TextIter start;
            buffer.get_start_iter (out start);
            buffer.place_cursor (start);
            buffer.set_modified (false);

            this.file = file;
            this.window_title.title = display_name;
            this.window_title.subtitle = file.get_parent ().peek_path ();
            string filename = this.file.peek_path().replace(".tex", ".pdf");
            this.pdfviewer.set_file("file://" + filename);
            this.compiler.path = file.peek_path ();
            this.compiler.dir = file.get_parent ().peek_path ();
        });
    }

    private void save_file_with_dialog () {
        this.filechooser.save.begin (this, null, (object, result) => {
            File? file = null;
            try {
                file = filechooser.save.end(result);
            } catch (Error e) {
                stderr.printf ("Unable to select file: %s", e.message);
                return;
            }
            this.save_file.begin (file);
        });
    }

    private string get_display_name(File? file) {
        string display_name;
        if (file == null) {
            return "New Document";
        }
        try {
            FileInfo info = file.query_info ("standard::display-name",
                                             FileQueryInfoFlags.NONE);
            display_name = info.get_attribute_string ("standard::display-name");
        } catch (Error e) {
            display_name = file.get_basename ();
        }
        return display_name;
    }

    private async void save_file (File file) {
        var display_name = this.get_display_name (file);
        GtkSource.Buffer buffer = this.source_view.buffer as GtkSource.Buffer;

        Gtk.TextIter start;
        buffer.get_start_iter (out start);

        Gtk.TextIter end;
        buffer.get_end_iter (out end);

        string? text = buffer.get_text (start, end, false);

        if (text == null || text.length == 0) return;

        var bytes = new Bytes.take (text.data);

        try{
            yield file.replace_contents_bytes_async (bytes,
                                                     null,
                                                     false,
                                                     FileCreateFlags.NONE,
                                                     null,
                                                     null);

        } catch (Error e) {
            stderr.printf ("Unable to save “%s”: %s\n", display_name, e.message);
            return;
        }

        this.file = file;
        this.window_title.title = display_name;
        this.window_title.subtitle = file.get_parent ().peek_path ();
        this.compiler.path = file.peek_path ();
        this.compiler.dir = file.get_parent ().peek_path ();
        buffer.set_modified (false);
    }

    private void on_save_action () {
        if (this.file == null) {
            this.save_file_with_dialog ();
        } else {
            this.save_file.begin(this.file);
        }
    }

    private void on_compile_action () {
        if (this.file == null) {
            message ("Create new file before compilation");
            return;
        }
        this.save_file.begin(this.file, (obj,res) => {
            this.save_file.end (res);
            compile_button.set_icon_name ("media-playback-stop-symbolic");
            pdfviewer.remove_log_entries ();
            compiler.compile.begin ((obj,res) => {
                CompilationResult compilation_result;
                compile_button.set_icon_name ("media-playback-start-symbolic");

                try{
                    compilation_result = compiler.compile.end (res);
                } catch (Error e) {
                    message("Running latexmk failed: %s", e.message);
                    return;
                }

                if (compilation_result.success) {
                    string filename = this.file.peek_path().replace(".tex", ".pdf");
                    this.pdfviewer.set_file("file://" + filename);
                } else {
                    this.pdfviewer.set_error (compilation_result.log);
                }
            });
        });
    }

    public void on_synctex_action () {
        if (this.file == null) {
            return;
        }
        var source = get_current_source_location();
        synctex_engine.synctex_forward.begin(source, (obj, res)=> {
            var rectangles = synctex_engine.synctex_forward.end(res);
            var pg = rectangles[0].page;
            var y = rectangles[0].y;
            this.pdfviewer.scroll_to (pg, (float) y);

            foreach (var rect in rectangles) {
                this.pdfviewer.add_synctex_rectangle (rect);
            }
        });
    }

    private void goto_log_entry(LogEntry entry) {
        message("row activated: %s", entry.message);
        var buffer = source_view.get_buffer ();
        Gtk.TextIter iter;
        buffer.get_iter_at_line (out iter, entry.location.line);
        source_view.scroll_to_iter (iter, 0.3, false, 0, 0);
        buffer.place_cursor(iter);
        source_view.grab_focus ();
    }

    private SourceLocation get_current_source_location() {
        var tex_path = file.peek_path ();
        var buffer = source_view.get_buffer ();
        var insert_mark = buffer.get_insert ();
        Gtk.TextIter iter;
        buffer.get_iter_at_mark (out iter, insert_mark);
        var line = iter.get_line ();
        var offset = iter.get_line_offset ();

        return SourceLocation () {
            file = tex_path,
            line = line,
            offset = offset,
            hint = null
            };
    }
}

