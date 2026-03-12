public struct CompilationResult {
    public bool success;
    public LogEntry[] log;
}

public struct LogEntry {
    public LogType type;
    public string message;
    public SourceLocation location;
}

public struct SourceLocation {
    public string file;
    public int line;
    public int? offset;
    public string? hint;
}

public enum LogType {
    ERROR,
    WARNING,
    BADBOX,
    INFO
}

public class Manuscript.Compiler : Object {

    Cancellable? compile_cancellable = null;
    public string? path { get; set; default = null; }
    public string? dir { get; set; default = null; }

    public Compiler () {
        Object ();
    }

    construct {

    }

    public async CompilationResult compile () throws Error {
        assert (path != null);
        assert (dir != null);

        if (compile_cancellable != null) {
            compile_cancellable.cancel ();
        }

        Subprocess proc;
        try {
            // watch-bus required to cancel mklatex
            proc = new Subprocess (SubprocessFlags.SEARCH_PATH_FROM_ENVP,
                                   "flatpak-spawn",
                                   "--host",
                                   "--watch-bus",
                                   "latexmk",
                                   "-synctex=1",
                                   "-pdf",
                                   "-halt-on-error",
                                   "-output-directory=" + dir,
                                   path);
        } catch (Error e) {
            message ("Latexmk spawn error: %s\n", e.message);
            throw e;
        }

        compile_cancellable = new Cancellable ();

        try {
            yield proc.wait_check_async (compile_cancellable);
        } catch (Error e) {
            compile_cancellable = null;
            if (e is IOError.CANCELLED) {
                // We need to force exit because of flatpak?
                proc.force_exit ();
                message ("mklatex cancelled");
                throw e;
            } else {
                message ("mklatex failed");
                var entries = yield parse_log ();
                return CompilationResult () { success = false, log = entries };
            }
        }
        compile_cancellable = null;
        var entries = yield parse_log ();
        return CompilationResult () { success = true, log = entries };
    }

    public async LogEntry[] parse_log () {
        assert (path != null);
        assert (dir != null);
        var entries = new LogEntry[0];
        var log_path = path.replace (".tex", ".log");
        var log_file = File.new_for_path (log_path);
        uint8[] contents;
        try {
            yield log_file.load_contents_async (null, out contents, null);
        } catch (Error e) {
            stderr.printf ("Unable to open the log file “%s“: %s",
                           log_path,
                           e.message);
            return entries;
        }
        var log_text = (string) contents;
        if (!log_text.validate ()) {
            stderr.printf ("Unable to load the contents of the log file “%s”: " +
                           "the file is not encoded with UTF-8\n",
                           path);
            return entries;
        }
        try {
            var lines = log_text.split ("\n");
            var error_re = new Regex ("^[ \t]*!(.*)$");
            var line_re = new Regex ("^\\s*l\\.(\\d+)\\s*(.*)$", RegexCompileFlags.MULTILINE);

            for (uint i = 0; i < lines.length; i++) {
                MatchInfo error_match;
                if (!error_re.match (lines[i], 0, out error_match))
                    continue;

                var message = error_match.fetch (1).strip ();

                // Find the next "l.<line> ..." line (TeX reports the line after the error).
                for (uint j = i + 1; j < lines.length; j++) {
                    MatchInfo match_info;
                    if (!line_re.match (lines[j], 0, out match_info))
                        continue;

                    var line_no = int.parse (match_info.fetch (1));
                    var hint = match_info.fetch (2);

                    var location = SourceLocation () {
                        file = path,
                        line = line_no,
                        hint = hint
                    };

                    entries += LogEntry () {
                        type = LogType.ERROR,
                        message = message,
                        location = location
                    };
                    break;
                }
            }
        } catch (Error e) {
            message ("Regex error in log parser: %s", e.message);
            return entries;
        }
        return entries;
    }

}

