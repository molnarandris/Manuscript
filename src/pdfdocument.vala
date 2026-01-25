class Manuscript.PdfDocument: Object {

    private Poppler.Document document;
    public int n_pages;
    public double height = 0;
    public double width = 0;
    public double[] y_offsets;

    public PdfDocument(string path) throws Error {
        document = new Poppler.Document.from_file ("file://" + path, null);
        n_pages = document.get_n_pages();
        y_offsets = new double[n_pages];
        double w, h;
        Poppler.Page page;
        for (int i=0; i<n_pages; i++) {
            y_offsets[i] = height;
            page = document.get_page(i);
            page.get_size(out w, out h);
            height += h;
            width = Math.fmax(width, w);
        }
    }

    public Poppler.Page get_page(int n) {
        return document.get_page(n);
    }
}
