latexeditor_sources = [
  'main.vala',
  'application.vala',
  'window.vala',
]

latexeditor_deps = [
  config_dep,
  dependency('gtk4'),
  dependency('libadwaita-1', version: '>= 1.4'),
]

latexeditor_sources += gnome.compile_resources('latexeditor-resources',
  'latexeditor.gresource.xml',
  c_name: 'latexeditor'
)

executable('latexeditor', latexeditor_sources,
  dependencies: latexeditor_deps,
  include_directories: config_inc,
       install: true,
)
