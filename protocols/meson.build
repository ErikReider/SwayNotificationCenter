dep_scanner = dependency('wayland-scanner', native: true)
prog_scanner = find_program(dep_scanner.get_variable(pkgconfig: 'wayland_scanner'))

output_type = 'private-code'
if dep_scanner.version().version_compare('< 1.14.91')
  output_type = 'code'
endif

protocol_sources = []

# xdg-activation-v1
xdg_activation_file = files('xdg-activation-v1.xml')

protocol_sources += custom_target(
  'xdg-activation-v1-client-protocol.h',
  command: [prog_scanner, 'client-header', '@INPUT@', '@OUTPUT@'],
  input: xdg_activation_file,
  output: 'xdg-activation-v1-client-protocol.h',
)

protocol_sources += custom_target(
  'xdg-activation-protocol.c',
  command: [prog_scanner, output_type, '@INPUT@', '@OUTPUT@'],
  input: xdg_activation_file,
  output: 'xdg-activation-protocol.c',
)

# ext-background-effect-v1
background_effect_file = files('ext-background-effect-v1.xml')

protocol_sources += custom_target(
  'ext-background-effect-v1-client-protocol.h',
  command: [prog_scanner, 'client-header', '@INPUT@', '@OUTPUT@'],
  input: background_effect_file,
  output: 'ext-background-effect-v1-client-protocol.h',
)

protocol_sources += custom_target(
  'ext-background-effect-protocol.c',
  command: [prog_scanner, output_type, '@INPUT@', '@OUTPUT@'],
  input: background_effect_file,
  output: 'ext-background-effect-protocol.c',
)

protocol_dep += declare_dependency(
  dependencies: [
    vala.find_library('xdg-activation-v1', dirs: meson.current_source_dir()),
    vala.find_library('ext-background-effect-v1', dirs: meson.current_source_dir()),
    dependency('wayland-client'),
  ],
  include_directories: include_directories('.'),
  sources: protocol_sources,
)
