/* application.vala
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

public class Manuscript.Application : Adw.Application {
    public Application () {
        Object (
            application_id: "com.github.molnarandris.manuscript",
            flags: ApplicationFlags.DEFAULT_FLAGS,
            resource_base_path: "/com/github/molnarandris/manuscript"
        );
    }

    construct {
        ActionEntry[] action_entries = {
            { "about", this.on_about_action },
            { "preferences", this.on_preferences_action },
            { "quit", this.quit }
        };
        this.add_action_entries (action_entries, this);
        this.set_accels_for_action ("app.quit", {"<control>q"});
        this.set_accels_for_action ("win.open", { "<Ctrl>o" });
        this.set_accels_for_action ("win.save-as", { "<Ctrl><Shift>s" });
        this.set_accels_for_action ("win.save", { "<Ctrl>s" });
        this.set_accels_for_action ("win.compile", { "F5" });
        this.set_accels_for_action ("win.synctex", { "F7" });
    }

    public override void activate () {
        base.activate ();
        GtkSource.init();
        var win = this.active_window ?? new Manuscript.Window (this);
        win.present ();
    }

    private void on_about_action () {
        string[] developers = { "Andras Molnar" };
        var about = new Adw.AboutDialog () {
            application_name = "manuscript",
            application_icon = "com.github.molnarandris.manuscript",
            developer_name = "Andras Molnar",
            translator_credits = _("translator-credits"),
            version = "0.1.0",
            developers = developers,
            copyright = "© 2025 Andras Molnar",
        };

        about.present (this.active_window);
    }

    private void on_preferences_action () {
        var dialog = new Manuscript.PreferencesDialog();
        dialog.present(this.active_window);
    }
}
