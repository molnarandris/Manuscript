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

[GtkTemplate (ui = "/com/github/molnarandris/latexeditor/window.ui")]
public class Latexeditor.Window : Adw.ApplicationWindow {
    [GtkChild]
    private unowned GtkSource.View source_view;

    public Window (Gtk.Application app) {
        Object (application: app);
    }

    construct {
        var open_action = new SimpleAction ("open", null);
        open_action.activate.connect (this.open_file_dialog);
        this.add_action (open_action);
    }

    private void open_file_dialog (Variant? parameter) {
        // Create a new file selection dialog, using the "open" mode
        // and keep a reference to it
        var filechooser = new Gtk.FileDialog ();
        filechooser.open.begin (this, null, (object, result) => {
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
        });
    }
}
