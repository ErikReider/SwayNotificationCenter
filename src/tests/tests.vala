namespace SwayNotificationCenter {
    static SwayncDaemon swaync_daemon;
    static string ? style_path;
    static string ? config_path;

    static Settings self_settings;

    public int main (string[] args) {
        Gtk.init (ref args);
        Test.init (ref args);

        Functions.init ();

        self_settings = new Settings ("org.erikreider.swaync");

        style_path = "./src/tests/style_test.json";
        config_path = "./src/tests/config_test.json";

        Test.add_func ("/ConfigModel/Test_paths", test_config_paths);

        Test.add_func ("/ConfigModel/Verify_custom_test_values",
                       test_config_values);

        return Test.run ();
    }

    private static inline void test_config_paths () {
        // Test invalid paths would result in the default path
        const string[] PATHS = { "~/@", "/@", "./@", "", null };
        foreach (var path in PATHS) {
            assert_false (path == Functions.get_config_path (path));
        }

        // Test valid paths
        // Relative path
        const string TEST_PATH1 = "./src/tests/config_test.json";
        assert_true (TEST_PATH1 == Functions.get_config_path (TEST_PATH1));

        // Home relative path ("~/...")
        string test_path2 = Path.build_filename (
            Environment.get_current_dir (),
            TEST_PATH1);
        string test_rel_path2 = Path.build_filename (
            Environment.get_current_dir ().replace (
                Environment.get_home_dir (), "~"),
            TEST_PATH1);
        assert_true (test_path2 == Functions.get_config_path (test_rel_path2));

        // Absolute path
        string test_path3 = Path.build_filename (
            Environment.get_current_dir (),
            TEST_PATH1);
        assert_true (test_path3 == Functions.get_config_path (test_path3));
    }

    private static inline void test_config_values () {
        ConfigModel.init (config_path);
        unowned ConfigModel i = ConfigModel.instance;
        // Position
        assert_true (i.positionX == PositionX.CENTER);
        assert_true (i.positionY == PositionY.BOTTOM);
        // Margins
        assert_true (i.control_center_margin_top == 12);
        assert_true (i.control_center_margin_bottom == 10);
        assert_true (i.control_center_margin_right == 40);
        assert_true (i.control_center_margin_left == 8);
        // Notification values
        assert_true (i.notification_icon_size == 83);
        print ("H: %i\n", i.notification_body_image_height);
        assert_true (i.notification_body_image_height == 140);
        assert_true (i.notification_body_image_width == 210);
        // Timeouts
        assert_true (i.timeout == 19);
        assert_true (i.timeout_low == 59);
        assert_true (i.timeout_critical == 1);
        // Control Center
        assert_true (i.control_center_width == 800);
        assert_true (i.control_center_height == 800);
        // Misc
        assert_true (i.notification_window_width == 50);
        assert_true (i.keyboard_shortcuts == false);
        assert_true (i.image_visibility == ImageVisibility.NEVER);
        assert_true (i.transition_time == 20);
        assert_true (i.hide_on_clear == true);
        assert_true (i.hide_on_action == false);
        assert_true (i.script_fail_notify == false);
    }
}
