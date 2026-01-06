public class Manuscript.LatexFile : Object {

    public signal void changed();

    public File file {get; construct;}
    public string basename {get; private set;}
    public string dir {get; private set;}
    public string path {get; private set;}
    private FileMonitor? monitor = null;
    private bool suppress_monitor = false;

    public LatexFile(File file) {
        Object(file: file);
    }

    construct {
        basename = file.get_basename();
        dir = file.get_parent().get_path();
        path = file.get_path();
        try{
            monitor = file.monitor_file(FileMonitorFlags.NONE, null);
        } catch (Error e) {
            message("Can't create file monitor for %s", path);
            return;
        }
        monitor.changed.connect( (src, dest, event) => {
            if (suppress_monitor) {
                return;
            }

            if (event == FileMonitorEvent.CHANGED) {
                changed();
            }
        });
    }

    public async string load_contents() throws Error {
        uint8[] contents;
        yield file.load_contents_async (null, out contents, null);
        if (!((string) contents).validate ()) {
            throw new IOError.INVALID_DATA("Invalid UTF-8 text");
        }

        return (string) contents;
    }

    public async void replace_contents(string contents) throws Error {
        var bytes = new Bytes.take (contents.data);
        suppress_monitor = true;
        try {
            yield file.replace_contents_bytes_async (
                bytes,
                null,
                false,
                FileCreateFlags.NONE,
                null,
                null
            );
        } finally {
            suppress_monitor = false;
        }
    }

    public string get_display_name() {
        string display_name;
        try {
            FileInfo info = file.query_info ("standard::display-name", FileQueryInfoFlags.NONE);
            display_name = info.get_attribute_string ("standard::display-name");
        } catch (Error e) {
            display_name = file.get_basename ();
        }
        return display_name;
    }
}
