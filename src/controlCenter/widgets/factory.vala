namespace SwayNotificationCenter.Widgets {
    public static Gtk.Widget ? get_widget_from_key (string key,
                                                    SwayncDaemon swaync_daemon,
                                                    NotiDaemon noti_daemon) {
        switch (key) {
            case "title":
                return new Title (swaync_daemon, noti_daemon);
            case "dnd":
                return new Dnd (swaync_daemon, noti_daemon);
            default: return null;
        }
    }
}
