python = import('python').find_installation('python3', modules: ['gi'])
hotplug_env = environment()
hotplug_env.set('SWAY_BIN', find_program('sway').full_path())
hotplug_env.set('SWAYMSG_BIN', find_program('swaymsg').full_path())
find_program('dbus-daemon')
find_program('gdbus')

test(
  'monitor-hotplug',
  python,
  args: [
    files('test-hotplug.py'),
    meson.project_build_root(),
    meson.project_source_root(),
  ],
  env: hotplug_env,
  suite: 'integration',
  timeout: 90,
)
