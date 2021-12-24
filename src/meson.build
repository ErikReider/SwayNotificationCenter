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

datadir = get_option('datadir')

# Zsh completion
if get_option('zsh-completions')
  zsh_files = files(
    '../completions/zsh/_swaync',
    '../completions/zsh/_swaync-client',
  )
  zsh_install_dir = join_paths(datadir, 'zsh', 'site-functions')

  install_data(zsh_files, install_dir: zsh_install_dir)
endif

# Bash completion
bash_comp = dependency('bash-completion', required: false)
if get_option('bash-completions')
  bash_files = files(
    '../completions/bash/swaync',
    '../completions/bash/swaync-client',
  )

  if bash_comp.found()
    bash_install_dir = bash_comp.get_variable(
      pkgconfig: 'completionsdir',
      pkgconfig_define: ['datadir', datadir]
    )
  else
    bash_install_dir = join_paths(datadir, 'bash-completion', 'completions')
  endif

  install_data(bash_files, install_dir: bash_install_dir)
endif

# Fish completion
fish_comp = dependency('fish', required: false)
if get_option('fish-completions')
  fish_files = files(
    '../completions/fish/swaync.fish',
    '../completions/fish/swaync-client.fish',
  )

  if fish_comp.found()
    fish_install_dir = fish_comp.get_variable(
      pkgconfig: 'completionsdir',
      pkgconfig_define: ['datadir', datadir]
    )
  else
    fish_install_dir = join_paths(datadir, 'fish', 'vendor_completions.d')
  endif

  install_data(fish_files, install_dir: fish_install_dir)
endif
