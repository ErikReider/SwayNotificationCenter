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
  # Widget: Backlight Slider
  'controlCenter/widgets/backlight/backlight.vala',
  'controlCenter/widgets/backlight/backlightUtil.vala',
  # Widget: Inhibitors
  'controlCenter/widgets/inhibitors/inhibitors.vala',
]

app_sources = [
  'main.vala',
  'animation/animation.vala',
  'orderedHashTable/orderedHashTable.vala',
  'configModel/configModel.vala',
  'swayncDaemon/swayncDaemon.vala',
  'notiDaemon/notiDaemon.vala',
  'notiModel/notiModel.vala',
  'notificationWindow/notificationWindow.vala',
  'notification/notification.vala',
  'notificationGroup/notificationGroup.vala',
  'controlCenter/controlCenter.vala',
  widget_sources,
  'blankWindow/blankWindow.vala',
  'functions.vala',
  constants,
]

app_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gio-unix-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('json-glib-1.0', version: '>= 1.0'),
  dependency('libhandy-1', version: '>= 1.2.3'),
  meson.get_compiler('c').find_library('gtk-layer-shell'),
  meson.get_compiler('c').find_library('m', required : true),
  meson.get_compiler('vala').find_library('posix'),
  dependency('gee-0.8'),
]

# Checks if the user wants scripting enabled
if get_option('scripting')
  add_project_arguments('-D', 'WANT_SCRIPTING', language: 'vala')
endif

# Checks if the user wants to compile with the PulseAudio dependency
if get_option('pulse-audio')
  add_project_arguments('-D', 'HAVE_PULSE_AUDIO', language: 'vala')
  app_deps += [
    dependency('libpulse'),
    dependency('libpulse-mainloop-glib'),
  ]
  app_sources += [
    # Widget: Volume
    'controlCenter/widgets/volume/volume.vala',
    'controlCenter/widgets/volume/pulseDaemon.vala',
    'controlCenter/widgets/volume/pulseDevice.vala',
    'controlCenter/widgets/volume/pulseSinkInput.vala',
    'controlCenter/widgets/volume/sinkInputRow.vala',
  ]
endif

# Detect libhandy version
libhandy = dependency('libhandy-1')
if libhandy.version() >= '1.3.9'
  add_project_arguments('-D', 'HAVE_LATEST_LIBHANDY', language: 'vala')
endif

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

app_sources += gnome.compile_resources('sway_notification_center-resources',
  'sway_notification_center.gresource.xml',
  c_name: 'sway_notification_center'
)

executable('swaync',
  app_sources,
  vala_args: args,
  dependencies: app_deps,
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
