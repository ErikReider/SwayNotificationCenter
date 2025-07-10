using XDG.Activation;
using SwayNotificationCenter;

public class XdgActivationHelper : Object {
    private static Wl.RegistryListener registry_listener = Wl.RegistryListener () {
        global = registry_handle_global,
    };
    private Activation * xdg_activation = null;

    public XdgActivationHelper () {
        unowned Wl.Display wl_display = Functions.get_wl_display ();
        var wl_registry = wl_display.get_registry ();
        wl_registry.add_listener (registry_listener, this);

        if (wl_display.roundtrip () < 0) {
            return;
        }
    }

    ~XdgActivationHelper () {
        if (xdg_activation != null) {
            xdg_activation->destroy ();
        }
    }

    private void registry_handle_global (Wl.Registry wl_registry, uint32 name,
                                         string @interface, uint32 version) {
        if (@interface == "xdg_activation_v1") {
            xdg_activation = wl_registry.bind<Activation> (name, ref Activation.iface, version);
            if (xdg_activation == null) {
                GLib.warning ("Could not bind to xdg_activation_v1 iface!");
            }
        }
    }

    private static void handle_done (void * data, Token activation_token,
                                     string token) {
        Value * value = (Value *) data;
        value->set_string (token.dup ());
    }

    private const TokenListener TOKEN_LISTENER = {
        handle_done,
    };

    public string ? get_token (Gtk.Widget widget) {
        if (xdg_activation == null) {
            return null;
        }

        unowned Wl.Display wl_display = Functions.get_wl_display ();
        unowned Gtk.Root ? root = widget.get_root ();
        if (root == null) {
            warning ("GDK Window is null");
            return null;
        }
        unowned Wl.Surface wl_surface = Functions.get_wl_surface (root.get_surface ());

        Value token_value = Value (typeof (string));
        token_value.set_string (null);

        Token * token = xdg_activation->get_activation_token ();
        token->add_listener (TOKEN_LISTENER, &token_value);
        token->set_surface (wl_surface);
        token->commit ();
        while (wl_display.dispatch () >= 0 && token_value.get_string () == null) {
            // noop
        }
        token->destroy ();

        unowned string token_str = token_value.get_string ();
        if (token_str != null && token_str.length > 0) {
            return token_str.dup ();
        }
        return null;
    }
}
