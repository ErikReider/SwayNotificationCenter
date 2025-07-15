# vim: syntax=spec
%global alt_pkg_name swaync

Name:       {{{ git_repo_name }}}
Version:    0.12.1
Release:    1%{?dist}
Summary:    Notification daemon with GTK GUI
Provides:   desktop-notification-daemon
Provides:   sway-notification-center = %{version}-%{release}
Provides:   %{alt_pkg_name} = %{version}-%{release}
License:    GPLv3
URL:        https://github.com/ErikReider/SwayNotificationCenter
VCS:        {{{ git_repo_vcs }}}
Source:     {{{ git_repo_pack }}}

BuildRequires:  meson >= 1.5.1
BuildRequires:  vala >= 0.56
BuildRequires:  scdoc
BuildRequires:  pkgconfig(gtk4) >= 4.16
BuildRequires:  pkgconfig(gtk4-layer-shell-0) >= 1.0.4
BuildRequires:  pkgconfig(json-glib-1.0) >= 1.0
BuildRequires:  pkgconfig(libadwaita-1) >= 1.6.5
BuildRequires:  pkgconfig(glib-2.0) >= 2.50
BuildRequires:  pkgconfig(gobject-introspection-1.0) >= 1.68
BuildRequires:  pkgconfig(gee-0.8) >= 0.20
BuildRequires:  pkgconfig(bash-completion)
BuildRequires:  pkgconfig(fish)
BuildRequires:  pkgconfig(libpulse)
BuildRequires:  pkgconfig(granite-7)
BuildRequires:  systemd-devel
BuildRequires:  systemd
BuildRequires:  sassc
BuildRequires:  blueprint-compiler >= 0.16

Requires:       gvfs
Requires:       libnotify
Requires:       dbus
%{?systemd_requires}

%description
A simple notification daemon with a GTK gui for notifications and the control center

%package bash-completion
BuildArch:      noarch
Summary:        Bash completion files for %{name}
Provides:       %{alt_pkg_name}-bash-completion = %{version}-%{release}

Requires:       bash-completion
Requires:       %{name} = %{version}-%{release}

%description bash-completion
This package installs Bash completion files for %{name}

%package zsh-completion
BuildArch:      noarch
Summary:        Zsh completion files for %{name}
Provides:       %{alt_pkg_name}-zsh-completion = %{version}-%{release}

Requires:       zsh
Requires:       %{name} = %{version}-%{release}

%description zsh-completion
This package installs Zsh completion files for %{name}

%package fish-completion
BuildArch:      noarch
Summary:        Fish completion files for %{name}
Provides:       %{alt_pkg_name}-fish-completion = %{version}-%{release}

Requires:       fish
Requires:       %{name} = %{version}-%{release}

%description fish-completion
This package installs Fish completion files for %{name}

%prep
{{{ git_repo_setup_macro }}}

%build
%meson
%meson_build

%install
%meson_install

%post
%systemd_user_post swaync.service

%preun
%systemd_user_preun swaync.service

%files
%doc README.md
%{_bindir}/swaync-client
%{_bindir}/swaync
%license COPYING
%config(noreplace) %{_sysconfdir}/xdg/swaync/configSchema.json
%config(noreplace) %{_sysconfdir}/xdg/swaync/config.json
%config(noreplace) %{_sysconfdir}/xdg/swaync/style.css
%{_userunitdir}/swaync.service
%{_datadir}/dbus-1/services/org.erikreider.swaync.service
%{_datadir}/glib-2.0/schemas/org.erikreider.swaync.gschema.xml
%{_mandir}/man1/swaync-client.1.gz
%{_mandir}/man1/swaync.1.gz
%{_mandir}/man5/swaync.5.gz

%files bash-completion
%{_datadir}/bash-completion/completions/swaync
%{_datadir}/bash-completion/completions/swaync-client

%files zsh-completion
%{_datadir}/zsh/site-functions/_swaync
%{_datadir}/zsh/site-functions/_swaync-client

%files fish-completion
%{_datadir}/fish/vendor_completions.d/swaync-client.fish
%{_datadir}/fish/vendor_completions.d/swaync.fish

# Changelog will be empty until you make first annotated Git tag.
%changelog
{{{ git_repo_changelog }}}
