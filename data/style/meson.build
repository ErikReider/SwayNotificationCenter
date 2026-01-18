# SCSS
sassc = find_program('sassc')
assert(sassc.found())

# SCSS Compilation
style_files += custom_target(
  'SCSS Compilation',
  input: 'style.scss',
  output: 'style.css',
  depend_files: files(run_command('find', '.', '-name', '*.scss').stdout().strip().split('\n')),
  install: true,
  install_dir: config_path,
  command: [
    sassc,
    '-t', 'expanded',
    '@INPUT@',
    '@OUTPUT@',
  ],
)
