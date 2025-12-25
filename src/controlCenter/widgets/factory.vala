namespace SwayNotificationCenter.Widgets {
    public static BaseWidget ?get_widget_from_key (owned string key, out bool is_notifications) {
        is_notifications = false;

        string[] key_seperated = key.split ("#");
        string suffix = "";
        if (key_seperated.length > 0) {
            key = key_seperated[0];
        }
        if (key_seperated.length > 1) {
            suffix = key_seperated[1];
        }
        BaseWidget widget;
        switch (key) {
            case "notifications" :
                is_notifications = true;
                message ("Loading widget: widget-notifications");
                return null;
            case "title":
                widget = new Title (suffix);
                break;
            case "dnd":
                widget = new Dnd (suffix);
                break;
            case "label":
                widget = new Label (suffix);
                break;
            case "mpris":
                widget = new Mpris.Mpris (suffix);
                break;
            case "menubar":
                widget = new Menubar (suffix);
                break;
            case "buttons-grid":
                widget = new ButtonsGrid (suffix);
                break;
            case "slider":
                widget = new Slider (suffix);
                break;
#if HAVE_PULSE_AUDIO
            case "volume":
                widget = new Volume (suffix);
                break;
#endif
            case "backlight":
                widget = new Backlight (suffix);
                break;
            case "inhibitors":
                widget = new Inhibitors (suffix);
                break;
            default:
                warning ("Could not find widget: \"%s\"!", key);
                return null;
        }
        message ("Loading widget: %s", widget.widget_name);
        return widget;
    }
}
