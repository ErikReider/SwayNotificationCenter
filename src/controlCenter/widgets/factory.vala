namespace SwayNotificationCenter.Widgets {
    public static BaseWidget ? get_widget_from_key (owned string key,
                                                    SwayncDaemon swaync_daemon,
                                                    NotiDaemon noti_daemon) {
        string[] key_seperated = key.split ("#");
        string suffix = "";
        if (key_seperated.length > 0) key = key_seperated[0];
        if (key_seperated.length > 1) suffix = key_seperated[1];
        BaseWidget widget;
        switch (key) {
            case "title":
                widget = new Title (suffix, swaync_daemon, noti_daemon);
                break;
            case "dnd":
                widget = new Dnd (suffix, swaync_daemon, noti_daemon);
                break;
            case "label":
                widget = new Label (suffix, swaync_daemon, noti_daemon);
                break;
            case "mpris":
                widget = new Mpris.Mpris (suffix, swaync_daemon, noti_daemon);
                break;
            default:
                warning ("Could not find widget: \"%s\"!", key);
                return null;
        }
        message ("Loading widget: %s", widget.widget_name);
        return widget;
    }
}
