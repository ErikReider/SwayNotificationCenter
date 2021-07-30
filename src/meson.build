app_sources = [
  'main.vala',
  'notiWindow/notiWindow.vala',
  'notification/notification.vala',
  'controlCenter/controlCenter.vala',
  'constants.vala',
  'functions.vala',
]

app_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('libhandy-1', version: '>= 1.0.0'),
  meson.get_compiler('c').find_library('gtk-layer-shell'),
  meson.get_compiler('c').find_library('m', required : true),
]

args = [
  '--target-glib=2.50',
  '--pkg=GtkLayerShell-0.1',
]

sysconfdir = get_option('sysconfdir')
gnome = import('gnome')

app_sources += gnome.compile_resources('sway_notificaton_center-resources',
  'sway_notificaton_center.gresource.xml',
  c_name: 'sway_notificaton_center'
)

executable('swaync',
  app_sources,
  vala_args: args,
  dependencies: app_deps,
  install: true,
)

executable('swaync-client',
  ['client.vala', 'constants.vala'],
  vala_args: args,
  dependencies: app_deps,
  install: true,
)

install_data('style.css', install_dir : sysconfdir + '/xdg/swaync')

