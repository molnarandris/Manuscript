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

    public File? file { get; private set; default=null; }

    public Window (Gtk.Application app) {
        Object (application: app);
    }

    construct {
        var open_action = new SimpleAction ("open", null);
        open_action.activate.connect (this.open_file_dialog);
        this.add_action (open_action);

        var save_as_action = new SimpleAction ("save-as", null);
        save_as_action.activate.connect (this.save_file_dialog);
        this.add_action (save_as_action);

        var save_action = new SimpleAction ("save", null);
        save_action.activate.connect (this.on_save_action);
        this.add_action (save_action);

        var lm = new GtkSource.LanguageManager();
        var latex = lm.get_language ("latex");
        var buffer = source_view.get_buffer () as GtkSource.Buffer;
        buffer.set_language (latex);
    }

    private void open_file_dialog (Variant? parameter) {
        // Create a new file selection dialog, using the "open" mode
        // and keep a reference to it
        var filechooser = new Gtk.FileDialog ();
        var filters = new ListStore ( typeof(Gtk.FileFilter) );

        var latex_filter = new Gtk.FileFilter();
        latex_filter.add_mime_type ("text/x-tex");
        filters.append (latex_filter);

        var text_filter = new Gtk.FileFilter();
        text_filter.add_mime_type ("text/plain");
        filters.append (text_filter);

        filechooser.set_filters (filters);
        filechooser.set_default_filter (latex_filter);

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

            this.file = file;
        });
    }

    private void save_file_dialog (Variant? parameter) {
        var filechooser = new Gtk.FileDialog ();
        var filters = new ListStore ( typeof(Gtk.FileFilter) );

        var latex_filter = new Gtk.FileFilter();
        latex_filter.add_mime_type ("text/x-tex");
        filters.append (latex_filter);

        var text_filter = new Gtk.FileFilter();
        text_filter.add_mime_type ("text/plain");
        filters.append (text_filter);

        filechooser.set_filters (filters);
        filechooser.set_default_filter (latex_filter);

        filechooser.save.begin (this, null, (object, result) => {
            File? file = null;
            try {
                file = filechooser.save.end(result);
            } catch (Error e) {
                stderr.printf ("Unable to select file: %s", e.message);
                return;
            }
            this.save_file (file);
        });
    }

    private void save_file (File file) {
        GtkSource.Buffer buffer = this.source_view.buffer as GtkSource.Buffer;

        Gtk.TextIter start;
        buffer.get_start_iter (out start);

        Gtk.TextIter end;
        buffer.get_end_iter (out end);

        string? text = buffer.get_text (start, end, false);

        if (text == null || text.length == 0) return;

        var bytes = new Bytes.take (text.data);

        file.replace_contents_bytes_async.begin (bytes,
                                                 null,
                                                 false,
                                                 FileCreateFlags.NONE,
                                                 null,
                                                 (object, result) => {
            string display_name;
            // Query the display name for the file
            try {
                FileInfo info = file.query_info ("standard::display-name",
                                                 FileQueryInfoFlags.NONE);
                display_name = info.get_attribute_string ("standard::display-name");
            } catch (Error e) {
                display_name = file.get_basename ();
            }

            try {
                file.replace_contents_async.end (result, null);
            } catch (Error e) {
                stderr.printf ("Unable to save “%s”: %s\n", display_name, e.message);
                return;
            }

            this.file = file;
        });
    }

    private void on_save_action(Variant? parameter) {
        if (this.file == null) {
            this.save_file_dialog (null);
        } else {
            this.save_file(this.file);
        }
    }
}
