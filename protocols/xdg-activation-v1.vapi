// vim: ft=vala

namespace XDG.Activation {
    [CCode (cheader_filename = "xdg-activation-v1-client-protocol.h", cname = "struct xdg_activation_v1", cprefix = "xdg_activation_v1_")]
    public class Activation : Wl.Proxy {
        [CCode (cheader_filename = "xdg-activation-v1-client-protocol.h", cname = "xdg_activation_v1_interface")]
        public static Wl.Interface iface;
        public void set_user_data (void * user_data);
        public void * get_user_data ();
        public uint32 get_version ();

        public void destroy ();

        public Token * get_activation_token ();
        public void activate (string token, Wl.Surface surface);
    }

    [CCode (cheader_filename = "xdg-activation-v1-client-protocol.h", cname = "enum xdg_activation_token_v1_error", cprefix = "XDG_ACTIVATION_TOKEN_V1_ERROR_", has_type_id = false)]
    public enum error {
        ALREADY_USED = 0,
    }

    [CCode (cheader_filename = "xdg-activation-v1-client-protocol.h", cname = "struct xdg_activation_token_v1", cprefix = "xdg_activation_token_v1_")]
    public class Token : Wl.Proxy {
        [CCode (cheader_filename = "xdg-activation-v1-client-protocol.h", cname = "xdg_activation_token_v1_listener")]
        public static Wl.Interface iface;
        public void set_user_data (void * user_data);
        public void * get_user_data ();
        public uint32 get_version ();
        public void destroy ();

        public int add_listener (TokenListener listener, void * data);

        public void set_serial (uint32 serial, Wl.Seat seat);
        public void set_app_id (string app_id);
        public void set_surface (Wl.Surface surface);
        public void commit ();
    }

    [CCode (cname = "struct xdg_activation_token_v1_listener", has_type_id = false)]
    public struct TokenListener {
        public TokenListenerDone done;
    }

    [CCode (has_target = false, has_typedef = false)]
    public delegate void TokenListenerDone (void * data, Token activation_token, string token);
}

