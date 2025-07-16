namespace SwayNotificationCenter.Widgets {
    public static BaseWidget ? get_widget_from_key (owned string key,
                                                    SwayncDaemon swaync_daemon,
                                                    NotiDaemon noti_daemon,
                                                    out bool is_notifications) {
        is_notifications = false;

        string[] key_seperated = key.split ("#");
        string suffix = "";
        if (key_seperated.length > 0) key = key_seperated[0];
        if (key_seperated.length > 1) suffix = key_seperated[1];
        BaseWidget widget;
        switch (key) {
            case "notifications":
                is_notifications = true;
                message ("Loading widget: widget-notifications");
                return null;
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
            case "menubar":
                widget = new Menubar (suffix, swaync_daemon, noti_daemon);
                break;
            case "buttons-grid":
                widget = new ButtonsGrid (suffix, swaync_daemon, noti_daemon);
                break;
            case "slider":
                widget = new Slider (suffix, swaync_daemon, noti_daemon);
                break;
#if HAVE_PULSE_AUDIO
            case "volume":
                widget = new Volume (suffix, swaync_daemon, noti_daemon);
                break;
#endif
            case "backlight":
                widget = new Backlight (suffix, swaync_daemon, noti_daemon);
                break;
            case "inhibitors":
                widget = new Inhibitors (suffix, swaync_daemon, noti_daemon);
                break;
            default:
                warning ("Could not find widget: \"%s\"!", key);
                return null;
        }
        message ("Loading widget: %s", widget.widget_name);
        return widget;
    }
}
