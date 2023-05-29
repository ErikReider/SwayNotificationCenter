# vim: syntax=spec
Name:       {{{ git_dir_name }}}
Version:    0.9.0
Release:    1%{?dist}
Summary:    Notification daemon with GTK GUI
Provides:   desktop-notification-daemon
License:    GPLv3
URL:        https://github.com/ErikReider/SwayNotificationCenter
VCS:        {{{ git_dir_vcs }}}
Source:     {{{ git_dir_pack }}}

BuildRequires:  meson >= 0.51.0
BuildRequires:  vala
BuildRequires:  scdoc
BuildRequires:  pkgconfig(gtk+-3.0) >= 3.22
BuildRequires:  pkgconfig(gtk-layer-shell-0) >= 0.1
BuildRequires:  pkgconfig(json-glib-1.0) >= 1.0
BuildRequires:  pkgconfig(libhandy-1) >= 1.4.0
BuildRequires:  pkgconfig(glib-2.0) >= 2.50
BuildRequires:  pkgconfig(gobject-introspection-1.0) >= 1.68
BuildRequires:  pkgconfig(gee-0.8) >= 0.20
BuildRequires:  pkgconfig(bash-completion)
BuildRequires:  pkgconfig(fish)
BuildRequires:  pkgconfig(libpulse)
BuildRequires:  systemd-devel
BuildRequires:  systemd

Requires:       dbus
%{?systemd_requires}

%description
A simple notification daemon with a GTK gui for notifications and the control center

%prep
{{{ git_dir_setup_macro }}}

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
%{_sysconfdir}/xdg/swaync/configSchema.json
%{_sysconfdir}/xdg/swaync/config.json
%{_sysconfdir}/xdg/swaync/style.css
%{_userunitdir}/swaync.service
%dir %{_datadir}/bash-completion
%dir %{_datadir}/bash-completion/completions
%{_datadir}/bash-completion/completions/swaync
%{_datadir}/bash-completion/completions/swaync-client
%{_datadir}/dbus-1/services/org.erikreider.swaync.service
%dir %{_datadir}/fish
%dir %{_datadir}/fish/vendor_completions.d
%{_datadir}/fish/vendor_completions.d/swaync-client.fish
%{_datadir}/fish/vendor_completions.d/swaync.fish
%dir %{_datadir}/zsh
%dir %{_datadir}/zsh/site-functions
%{_datadir}/zsh/site-functions/_swaync
%{_datadir}/zsh/site-functions/_swaync-client
%{_datadir}/glib-2.0/schemas/org.erikreider.swaync.gschema.xml
%{_mandir}/man1/swaync-client.1.gz
%{_mandir}/man1/swaync.1.gz
%{_mandir}/man5/swaync.5.gz

# Changelog will be empty until you make first annotated Git tag.
%changelog
{{{ git_dir_changelog }}}
