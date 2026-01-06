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
    private unowned Adw.WindowTitle window_title;
    [GtkChild]
    private unowned Gtk.Button compile_button;
    [GtkChild]
    private unowned Manuscript.Pdfviewer pdfviewer;
    [GtkChild]
    private unowned Manuscript.Editor editor;

    private Compiler compiler = new Compiler();
    private Synctex synctex_engine = new Synctex();

    public Window (Gtk.Application app) {
        Object (application: app);
    }

    construct {
        ActionEntry[] actions = {
            {"open", () => open_async.begin()},
            {"save-as", () => save_as_async.begin()},
            {"save", () => save_async.begin()},
            {"compile", on_compile_action},
            {"synctex", () => synctex_async.begin()},
        };

        add_action_entries (actions, this);

        pdfviewer.error_activated.connect (editor.goto_log_entry);
        editor.notify["file"].connect((s,p) => {
            update_window_title ();
            update_compiler_state ();
            update_pdfviewer ();
        });
        editor.notify["modified"].connect((s,p) => {
            update_window_title();
        });
    }

    private void update_window_title () {
        string title, subtitle;

        if (editor.file == null) {
            title = "New Document";
            subtitle = "unsaved";
        } else {
            title = editor.file.basename;
            subtitle = editor.file.dir;
        }

        window_title.subtitle = subtitle;
        window_title.title = editor.modified ? "• " + title : title;
    }

    private void update_compiler_state () {
        if (editor.file == null)
            return;

        compiler.path = editor.file.path;
        compiler.dir  = editor.file.dir;
    }

    private void update_pdfviewer () {
        if (editor.file == null)
            return;

        var pdf = editor.file.path.replace (".tex", ".pdf");
        pdfviewer.set_file ("file://" + pdf);
    }

    private async void open_async () {
        try {
            yield editor.open_file_with_dialog ();
        } catch (Error e) {
            var dialog = new Adw.AlertDialog (_("Can't open file"), null);
            dialog.add_response("close", _("Close"));
            dialog.format_body ("%s", e.message);
            dialog.present(root);
        }
    }

    private async void save_as_async () {
        try {
            yield editor.save_with_dialog ();
        } catch (Error e) {
            show_save_error_dialog(e);
        }
    }

    private async void save_async () {
        try {
            yield editor.save ();
        } catch (Error e) {
            show_save_error_dialog(e);
        }
    }

    private void show_save_error_dialog (Error e) {
        var dialog = new Adw.AlertDialog (_("Can't save file"), null);
        dialog.add_response("close", _("Close"));
        dialog.format_body ("%s", e.message);
        dialog.present(root);
    }

    private void on_compile_action () {
        if (editor.file == null) {
            message ("Create new file before compilation");
            return;
        }
        editor.save.begin((obj,res) => {
            editor.save.end (res);
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
                    string filename = editor.file.path.replace(".tex", ".pdf");
                    pdfviewer.set_file("file://" + filename);
                } else {
                    pdfviewer.set_error (compilation_result.log);
                }
            });
        });
    }

    private async void synctex_async () {
        if (editor.file == null) {
            return;
        }

        var source = editor.get_cursor_location();
        SynctexResult[] rects = {};
        try {
            rects = yield synctex_engine.synctex_forward(source);
        } catch (Error e) {
            message("Synctex error: %s", e.message);
            return;
        }

        pdfviewer.scroll_to (rects[0].page, (float) rects[0].y);
        foreach (var rect in rects) {
            pdfviewer.add_synctex_rectangle (rect);
        }
    }
}

