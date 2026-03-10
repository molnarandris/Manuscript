public struct SynctexResult {
    int page;
    double x;
    double y;
    double width;
    double height;
}

public class Manuscript.Synctex : Object {

    public Synctex () {
        Object();
    }

    construct {
    }

    private string get_position_string(SourceLocation source) {
        return source.line.to_string("%i") + ":" +
               source.offset.to_string("%i") + ":" +
               source.file;
    }

    public async Gee.HashMap<int, Gee.ArrayList<Graphene.Rect?>> synctex_forward (SourceLocation source) throws Error {
        Subprocess proc;
        var position = get_position_string(source);
        var pdf_path = source.file.replace(".tex", ".pdf");
        Gee.HashMap<int, Gee.ArrayList<Graphene.Rect?>> rects_by_page =
            new Gee.HashMap<int, Gee.ArrayList<Graphene.Rect?>> ();
        try{
            // watch-bus required to cancel
            proc = new Subprocess (SubprocessFlags.SEARCH_PATH_FROM_ENVP|
                                   SubprocessFlags.STDOUT_PIPE|
                                   SubprocessFlags.STDERR_PIPE,
                                   "flatpak-spawn", "--host", "--watch-bus",
                                   "synctex", "view",
                                   "-i", position,
                                   "-o", pdf_path);
        } catch (Error e) {
            stderr.printf ("Synctex spawn error: %s\n", e.message);
            throw e;
        }

        string stdout, stderr;
        try {
            yield proc.communicate_utf8_async (null, null, out stdout, out stderr);
        } catch (Error e) {
            message("Synctex failed: %s", e.message);
            throw e;
        }
        try {
            Regex record;
            MatchInfo match_info;
            record = new Regex("Page:(.*)\n.*\n.*\nh:(.*)\nv:(.*)\nW:(.*)\nH:(.*)");
            record.match (stdout, 0, out match_info);
            do {
                var page   = int.parse (match_info.fetch(1)) - 1;
                var rect = Graphene.Rect ();
                var x = float.parse(match_info.fetch(2));
                var y = float.parse(match_info.fetch(3));
                var w = float.parse(match_info.fetch(4));
                var h = float.parse(match_info.fetch(5));
                rect.init(x, Math.fmaxf (0,y-h), w,h);
                var list = rects_by_page.get (page);
                if (list == null) {
                    list = new Gee.ArrayList<Graphene.Rect?> ();
                    rects_by_page.set (page, list);
                }
                list.add (rect);
            } while (match_info.next ());
        } catch (Error e) {
            message("Regex error in synctex engine: %s", e.message);
            throw e;
        }
        return rects_by_page;
    }

}
