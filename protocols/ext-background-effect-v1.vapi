namespace Ext.BackgroundEffect {
    [CCode (cheader_filename = "ext-background-effect-v1-client-protocol.h", cname = "struct ext_background_effect_manager_v1", cprefix = "ext_background_effect_manager_v1_")]
    public class Manager : Wl.Proxy {
        [CCode (cheader_filename = "ext-background-effect-v1-client-protocol.h", cname = "ext_background_effect_manager_v1_interface")]
        public static Wl.Interface iface;
        public void set_user_data (void * user_data);
        public void * get_user_data ();
        public uint32 get_version ();

        public void destroy ();
        public int add_listener (ManagerListener listener, void * data);
        public Surface * get_background_effect (Wl.Surface surface);
    }

    [CCode (cheader_filename = "ext-background-effect-v1-client-protocol.h", cname = "enum ext_background_effect_manager_v1_error", cprefix = "EXT_BACKGROUND_EFFECT_MANAGER_V1_ERROR_", has_type_id = false)]
    public enum ManagerError {
        BACKGROUND_EFFECT_EXISTS = 0,
    }

    [CCode (cheader_filename = "ext-background-effect-v1-client-protocol.h", cname = "enum ext_background_effect_manager_v1_capability", cprefix = "EXT_BACKGROUND_EFFECT_MANAGER_V1_CAPABILITY_", has_type_id = false)]
    [Flags]
    public enum Capability {
        BLUR = 1,
    }

    [CCode (cheader_filename = "ext-background-effect-v1-client-protocol.h", cname = "struct ext_background_effect_manager_v1_listener", has_type_id = false)]
    public struct ManagerListener {
        public ManagerListenerCapabilities capabilities;
    }

    [CCode (has_target = false, has_typedef = false)]
    public delegate void ManagerListenerCapabilities (void * data, Manager manager, uint32 flags);

    [CCode (cheader_filename = "ext-background-effect-v1-client-protocol.h", cname = "struct ext_background_effect_surface_v1", cprefix = "ext_background_effect_surface_v1_")]
    public class Surface : Wl.Proxy {
        [CCode (cheader_filename = "ext-background-effect-v1-client-protocol.h", cname = "ext_background_effect_surface_v1_interface")]
        public static Wl.Interface iface;
        public void set_user_data (void * user_data);
        public void * get_user_data ();
        public uint32 get_version ();

        public void destroy ();
        public void set_blur_region (Wl.Region ? region);
    }

    [CCode (cheader_filename = "ext-background-effect-v1-client-protocol.h", cname = "enum ext_background_effect_surface_v1_error", cprefix = "EXT_BACKGROUND_EFFECT_SURFACE_V1_ERROR_", has_type_id = false)]
    public enum SurfaceError {
        SURFACE_DESTROYED = 0,
    }
}
