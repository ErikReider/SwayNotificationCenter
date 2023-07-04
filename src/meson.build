# Sets the version to a vala variable in Constants.vala
version = '@0@'.format(meson.project_version())
git = find_program('git', native: true, required: false)
if git.found()
  git_commit = run_command([git, 'rev-parse', '--short', 'HEAD'], check: false)
  git_branch = run_command([git, 'rev-parse', '--abbrev-ref', 'HEAD'], check: false)
  if git_commit.returncode() == 0 and git_branch.returncode() == 0
    version = '@0@ (git-@1@, branch \'@2@\')'.format(
      meson.project_version(),
      git_commit.stdout().strip(),
      git_branch.stdout().strip(),
    )
  endif
endif
version = 'swaync @0@'.format(version)
const_config_data = configuration_data()
const_config_data.set_quoted('VERSION', version)
const_config_data.set_quoted('VERSION_NUM', meson.project_version())
constants = configure_file(
  input : 'constants.vala.in',
  output : 'constants.vala',
  configuration : const_config_data
)

widget_sources = [
  # Helpers
  'controlCenter/widgets/baseWidget.vala',
  'controlCenter/widgets/factory.vala',
  # Widget: Notifications
  'controlCenter/widgets/notifications/notifications.vala',
  # Widget: Title
  'controlCenter/widgets/title/title.vala',
  # Widget: Dnd
  'controlCenter/widgets/dnd/dnd.vala',
  # Widget: Label
  'controlCenter/widgets/label/label.vala',
  # Widget: MPRIS
  'controlCenter/widgets/mpris/mpris.vala',
  'controlCenter/widgets/mpris/interfaces.vala',
  'controlCenter/widgets/mpris/mpris_player.vala',
  # Widget: Menubar
  'controlCenter/widgets/menubar/menubar.vala',
  # Widget: Buttons Grid
  'controlCenter/widgets/buttonsGrid/buttonsGrid.vala',
  # Widget: Volume
  'controlCenter/widgets/volume/volume.vala',
  'controlCenter/widgets/volume/pulseDaemon.vala',
  'controlCenter/widgets/volume/pulseDevice.vala',
  'controlCenter/widgets/volume/pulseSinkInput.vala',
  'controlCenter/widgets/volume/sinkInputRow.vala',
  # Widget: Backlight Slider
  'controlCenter/widgets/backlight/backlight.vala',
  'controlCenter/widgets/backlight/backlightUtil.vala',
  # Widget: Inhibitors
  'controlCenter/widgets/inhibitors/inhibitors.vala',
]

app_sources = [
  'main.vala',
  'functions.vala',
  'configModel/configModel.vala',
  'orderedHashTable/orderedHashTable.vala',
  'customWidgets/iterBox.vala',
  'customWidgets/blankWindow.vala',
  'customWidgets/dismissibleWidget.vala',
  'customWidgets/scaledImage.vala',
  'swayncDaemon/swayncDaemon.vala',
  'notiDaemon/notiDaemon.vala',
  'notiModel/notiModel.vala',
  'notificationWindow/notificationWindow.vala',
  'notification/notification.vala',
  'notification/notificationContent.vala',
  'controlCenter/controlCenter.vala',
  'emptyWindow/emptyWindow.vala',
  widget_sources,
  constants,
]

# vapi_dir = meson.current_source_dir() / 'vapi'

libadwaita_version = '>= 1.3.2'
libadwaita_dep = dependency(
  'libadwaita-1',
  # 'libadwaita-0',
  version: libadwaita_version,
  required: false,
)
if not libadwaita_dep.found()
  libadwaita_project = subproject(
    'libadwaita',
    version: libadwaita_version,
  )
  libadwaita_dep = declare_dependency(
    dependencies: [
      libadwaita_project.get_variable('libadwaita_dep'),
      libadwaita_project.get_variable('libadwaita_vapi'),
    ],
  )
  libadwaita_vapi = meson.build_root() / 'subprojects' / 'libadwaita' / 'src'
  add_project_arguments(['--vapidir', libadwaita_vapi], language: 'vala')
endif

# libadwaita = dependency(
#   'libadwaita-1',
#   version: '>= 1.3.2',
#   fallback: ['libadwaita', 'libadwaita_dep'],
# )

layershell_version = '>= 1.0.0'
# layershell_proj = subproject(
#   'gtk4-layer-shell',
#   required: false,
#   version: layershell_version,
# )
# layershell_dep = dependency(
#   'gtk4-layer-shell-0',
#   fallback: ['gtk4-layer-shell', 'gtk_layer_shell'],
#   version: layershell_version,
#   required: false,
# )
# layershell_vapi = ''
# if not layershell.found()
#   layershell_project = subproject(
#     'gtk4-layer-shell',
#     version: layershell_version,
#   )
#   layershell = declare_dependency(
#     dependencies: [
#       layershell_project.get_variable('gtk_layer_shell'),
#       layershell_project.get_variable('vapi'),
#     ],
#   )
#   layershell_vapi = meson.build_root() / 'subprojects' / 'gtk4-layer-shell' / 'src'
# endif

# if not layershell_dep.found()
#   layershell_proj = subproject(
#     'gtk4-layer-shell',
#     required: false,
#     version: layershell_version,
#   )
# # layershell_lib = layershell_proj.get_variable('gtk_layer_shell_lib')
#   layershell_dep = layershell_proj.get_variable('gtk_layer_shell')
#   layershell_vapi = layershell_proj.get_variable('vapi')
# # layershell = dependency('gtk4-layer-shell-0', version: layershell_version)
# endif

app_deps = [
  # layershell_lib,
  # layershell_dep,
  # layershell_vapi,
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gio-unix-2.0', version: '>= 2.50'),
  dependency('gtk4', version: '>= 4.11.3'),
  libadwaita_dep,
  # libadwaita,
  # dependency('libadwaita-1', version: '>= 1.3.2'),
  dependency('json-glib-1.0', version: '>= 1.0'),
  dependency('gtk4-layer-shell-0', version: layershell_version),
  # dependency('libhandy-1', version: '>= 1.2.3'),
  meson.get_compiler('c').find_library('m', required : true),
  meson.get_compiler('vala').find_library('posix'),
  dependency('gee-0.8'),
  dependency('libpulse'),
  dependency('libpulse-mainloop-glib'),
]

# Checks if the user wants scripting enabled
if get_option('scripting')
    add_project_arguments('-D', 'WANT_SCRIPTING', language: 'vala')
endif

# Detect libhandy version
# libhandy = dependency('libhandy-1')
# if libhandy.version() >= '1.3.9'
#     add_project_arguments('-D', 'HAVE_LATEST_LIBHANDY', language: 'vala')
# endif

# Detect gtk-layer-shell version
# gtk_layer_shell = dependency(
#   'gtk-layer-shell-0',
#   fallback: ['gtk-layer-shell-0', 'gtk-layer-shell'],
# )
# if gtk_layer_shell.version() >= '0.6.0'
#     add_project_arguments('-D', 'HAVE_LATEST_GTK_LAYER_SHELL', language: 'vala')
# endif

args = [
  '--target-glib=2.74',
  # '--pkg=GtkLayerShell-0.1',
  '--library=gtk4',
  '--library=libadwaita-1',
]

sysconfdir = get_option('sysconfdir')

app_resources += gnome.compile_resources('sway_notification_center-resources',
  'swaync_template.gresource.xml',
  c_name: 'sway_notification_center'
)

# add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

executable('swaync',
  [ app_sources, app_resources ],
  vala_args: args,
  dependencies: app_deps,
  # link_with: [layershell_lib],
  install: true,
)

executable('swaync-client',
  ['client.vala', constants],
  vala_args: args,
  dependencies: app_deps,
  install: true,
)

config_path = join_paths(sysconfdir, 'xdg/swaync')

config_data = configuration_data()
config_data.set_quoted('JSONPATH', join_paths('/', config_path, 'configSchema.json'))
config_json = configure_file(
  input : 'config.json.in',
  output : 'config.json',
  configuration : config_data
)

install_data('style.css', install_dir : config_path)
install_data(config_json, install_dir : config_path)
install_data('configSchema.json', install_dir : config_path)
