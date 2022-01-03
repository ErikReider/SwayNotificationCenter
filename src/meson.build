app_sources = [
  'main.vala',
  'configModel/configModel.vala',
  'notiDaemon/notiDaemon.vala',
  'notiModel/notiModel.vala',
  'notiWindow/notiWindow.vala',
  'notification/notification.vala',
  'ccDaemon/ccDaemon.vala',
  'controlCenter/controlCenter.vala',
  'controlCenter/topAction/topAction.vala',
  'constants.vala',
  'functions.vala',
]

app_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('json-glib-1.0', version: '>= 1.0'),
  dependency('libhandy-1', version: '>= 1.2.0'),
  meson.get_compiler('c').find_library('gtk-layer-shell'),
  meson.get_compiler('c').find_library('m', required : true),
]

# Detect gtk-layer-shell version
gtk_layer_shell = dependency(
  'gtk-layer-shell-0',
  fallback: ['gtk-layer-shell-0', 'gtk-layer-shell'],
)
if gtk_layer_shell.version() >= '0.6.0'
    add_project_arguments('-D', 'HAVE_LATEST_GTK_LAYER_SHELL', language: 'vala')
endif

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

install_data('style.css', install_dir : join_paths(sysconfdir, 'xdg/swaync'))
install_data('config.json', install_dir : join_paths(sysconfdir, 'xdg/swaync'))
