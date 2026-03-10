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
    private unowned Manuscript.PdfPane pdf_pane;
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
            {"compile", () => compile_async.begin()},
            {"synctex", () => synctex_async.begin()},
        };

        add_action_entries (actions, this);

        pdf_pane.error_activated.connect (editor.goto_log_entry);
        editor.notify["file"].connect((s,p) => {
            update_window_title ();
            update_compiler_state ();
            update_pdf_pane ();
        });
        editor.notify["modified"].connect((s,p) => {
            update_window_title();
        });

        pdf_pane.synctex_back.connect (synctex_back);
    }

    private void synctex_back(string path, int p, double x, double y){
        synctex_engine.synctex_backwards.begin (path, p, x, y, (obj,res) => {
            var line = synctex_engine.synctex_backwards.end (res);
            editor.scroll_to(line, 0);
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

    private void update_pdf_pane () {
        if (editor.file == null)
            return;

        var pdf = editor.file.path.replace (".tex", ".pdf");
        pdf_pane.set_path (pdf);
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
            show_error_dialog("Can't save file", e.message);
        }
    }

    private async void save_async () {
        try {
            yield editor.save ();
        } catch (Error e) {
            show_error_dialog(_("Can't save file"), e.message);
        }
    }

    private void show_error_dialog (string title, string body) {
        var dialog = new Adw.AlertDialog (title, null);
        dialog.add_response("close", _("Close"));
        dialog.format_body (body);
        dialog.present(root);
    }

    private async void compile_async () {
        string error_title = "Error during compilation";

        if (editor.file == null) {
            show_error_dialog(error_title, "Save the file before compiling");
            return;
        }

        try {
            yield editor.save ();
        } catch (Error e) {
            show_error_dialog (error_title, "Error saving the file: %s".printf (e.message));
            return;
        }

        compile_button.set_icon_name ("media-playback-stop-symbolic");
        pdf_pane.remove_log_entries ();

        CompilationResult compilation_result;
        try {
            compilation_result = yield compiler.compile ();
        } catch (Error e) {
            show_error_dialog (error_title, "Running latexmk failed: %s".printf(e.message));
            compile_button.set_icon_name ("media-playback-start-symbolic");
            return;
        }

        compile_button.set_icon_name ("media-playback-start-symbolic");

        if (compilation_result.success) {
            string filename = editor.file.path.replace (".tex", ".pdf");
            pdf_pane.set_path (filename);
        } else {
            pdf_pane.set_error (compilation_result.log);
        }
    }

    private async void synctex_async () {
        if (editor.file == null) {
            return;
        }

        var source = editor.get_cursor_location();
        Gee.HashMap<int, Gee.ArrayList<Graphene.Rect?>> synctex_results;
        try {
            synctex_results = yield synctex_engine.synctex_forward(source);
        } catch (Error e) {
            message("Synctex error: %s", e.message);
            return;
        }

        pdf_pane.add_synctex_rectangles (synctex_results);
    }
}

