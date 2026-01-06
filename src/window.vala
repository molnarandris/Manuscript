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

    private ActionEntry[] actions = {
            {"open", on_open_action},
            {"save-as", on_save_as_action},
            {"save", on_save_action},
            {"compile", on_compile_action},
            {"synctex", on_synctex_action},
        };

    construct {
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
        var title = editor.file.basename ?? "New Document";
        if (editor.modified) {
            window_title.title = "• " + title;
        } else {
            window_title.title = title;
        }
        window_title.subtitle = editor.file.dir ?? "unsaved";
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

    private void on_open_action () {
        editor.open_file_with_dialog.begin();
    }

    private void on_save_as_action () {
        editor.save_file_with_dialog.begin();
    }

    private void on_save_action () {
        if (editor.file == null) {
            editor.save_file_with_dialog.begin();
        } else {
            editor.save_file.begin();
        }
    }

    private void on_compile_action () {
        if (editor.file == null) {
            message ("Create new file before compilation");
            return;
        }
        editor.save_file.begin((obj,res) => {
            editor.save_file.end (res);
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

    public void on_synctex_action () {
        if (editor.file == null) {
            return;
        }
        var source = editor.get_cursor_location();
        synctex_engine.synctex_forward.begin(source, (obj, res)=> {
            var rectangles = synctex_engine.synctex_forward.end(res);
            var pg = rectangles[0].page;
            var y = rectangles[0].y;
            pdfviewer.scroll_to (pg, (float) y);

            foreach (var rect in rectangles) {
                pdfviewer.add_synctex_rectangle (rect);
            }
        });
    }
}

