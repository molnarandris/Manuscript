manuscript_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
  'pdfviewer.vala',
  'completion.vala',
  'preferences-dialog.vala',
]

blueprints = custom_target('blueprints',
  input: files(
    'window.blp',
    'shortcuts-dialog.blp',
    'pdfviewer.blp',
    'preferences-dialog.blp',
  ),
  output: '.',
  command: [find_program('blueprint-compiler'), 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
)

manuscript_deps = [
  config_dep,
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.4'),
  dependency('gtksourceview-5'),
  dependency('poppler-glib'),
]

manuscript_sources += gnome.compile_resources('manuscript-resources',
  'manuscript.gresource.xml',
  c_name: 'manuscript',
  dependencies: blueprints,
)

executable('manuscript', manuscript_sources,
  dependencies: manuscript_deps,
  include_directories: config_inc,
       install: true,
)
