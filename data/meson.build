install_data('org.erikreider.swaync.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0/schemas')
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif

# SCSS Dependency
sassc = find_program('sassc')
assert(sassc.found())

# SCSS Compilation
style_css = custom_target(
  'SCSS Compilation',
  build_by_default: true,
  build_always_stale: true,
  input : 'style/style.scss',
  output : 'style.css',
  install: true,
  install_dir: config_path,
  command : [
    sassc,
    '-t',
    'expanded',
    '@INPUT@',
    '@OUTPUT@'
  ],
)

message(style_css.full_path())

blueprints = custom_target('blueprints',
  input: files(run_command('find', '.', '-name', '*.blp').stdout().strip().split('\n')),
  output: '.',
  command: [
    find_program('blueprint-compiler', required: true),
    'batch-compile',
    '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'
  ],
  build_always_stale: true,
  build_by_default: true,
)

app_resources += gnome.compile_resources('sway_notification_center-resources',
  'sway_notification_center.gresource.xml',
    dependencies: [ blueprints ],
  c_name: 'sway_notification_center'
)
