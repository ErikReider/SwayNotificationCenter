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
  'controlCenter/widgets/shared/toggleButton.vala',
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
  'fadedViewport/fadedViewport.vala',
  'notificationWindow/notificationWindow.vala',
  'notification/notification.vala',
  'notificationGroup/notificationGroup.vala',
  'controlCenter/controlCenter.vala',
  widget_sources,
  'blankWindow/blankWindow.vala',
  'functions.vala',
  'WaylandUtils/WaylandUtils.c',
  'WaylandUtils/WaylandUtils.vala',
  'xdg_activation.vala',
  constants,
]

assert(vala.version() >= '0.56')

app_deps = [
  dependency('gio-2.0', version: '>= 2.50'),
  dependency('gio-unix-2.0', version: '>= 2.50'),
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('json-glib-1.0', version: '>= 1.0'),
  dependency('libhandy-1', version: '>= 1.8.0'),
  dependency('granite', version: '>= 6.2.0'),
  dependency('gtk-layer-shell-0',
    fallback: ['gtk-layer-shell-0', 'gtk-layer-shell'],
    version: '>= 0.8.0'
  ),
  cc.find_library('m', required : true),
  vala.find_library('posix'),
  dependency('gee-0.8'),
  dependency('wayland-client'),
  protocol_dep,
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

args = [
  '--target-glib=2.50',
  '--pkg=GtkLayerShell-0.1',
]

app_resources += gnome.compile_resources('sway_notification_center-resources',
  'sway_notification_center.gresource.xml',
  c_name: 'sway_notification_center'
)

executable('swaync',
  [ app_sources, app_resources ],
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

config_data = configuration_data()
config_data.set_quoted('JSONPATH', join_paths('/', config_path, 'configSchema.json'))
config_json = configure_file(
  input : 'config.json.in',
  output : 'config.json',
  configuration : config_data
)

install_data(config_json, install_dir : config_path)
install_data('configSchema.json', install_dir : config_path)
