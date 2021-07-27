sway_notificaton_center_sources = [
  'main.vala',
  'window/window.vala',
  'notification/notification.vala',
  'controlCenter/controlCenter.vala',
  'constants.vala',
]

sway_notificaton_center_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('libhandy-1', version: '>= 1.0.0'),
  meson.get_compiler('c').find_library('gtk-layer-shell')
]

gnome = import('gnome')

sway_notificaton_center_sources += gnome.compile_resources('sway_notificaton_center-resources',
  'sway_notificaton_center.gresource.xml',
  c_name: 'sway_notificaton_center'
)

executable('sway-nc',
  sway_notificaton_center_sources,
  vala_args: [ '--target-glib=2.50', '--pkg=GtkLayerShell-0.1' ],
  dependencies: sway_notificaton_center_deps,
  install: true,
)

executable('sway-nc-client',
  ['client.vala', 'constants.vala'],
  vala_args: [ '--target-glib=2.50', '--pkg=GtkLayerShell-0.1' ],
  dependencies: sway_notificaton_center_deps,
  install: true,
)
