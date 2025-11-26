latexeditor_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
]

blueprints = custom_target('blueprints',
  input: files(
    'window.blp',
    'shortcuts-dialog.blp',
  ),
  output: '.',
  command: [find_program('blueprint-compiler'), 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
)

latexeditor_deps = [
  config_dep,
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.4'),
  dependency('gtksourceview-5'),
]

latexeditor_sources += gnome.compile_resources('latexeditor-resources',
  'latexeditor.gresource.xml',
  c_name: 'latexeditor',
  dependencies: blueprints,
)

executable('latexeditor', latexeditor_sources,
  dependencies: latexeditor_deps,
  include_directories: config_inc,
       install: true,
)
