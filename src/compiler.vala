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
    public string? file;
    public int? line;

    public string? hint;
}

public enum LogType{
    ERROR,
    WARNING,
    BADBOX,
    INFO
}

public struct SynctexResult {
    int page;
    double x;
    double y;
    double width;
    double height;
}
