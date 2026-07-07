/*
 * Compositor-level background blur via ext-background-effect-v1 protocol.
 *
 * All Wayland proxy types (Wl.Registry, Manager, Wl.Compositor, Wl.Region)
 * are [Compact] classes with a free_function — Vala auto-destroys owned
 * instances when they go out of scope.  To avoid premature destruction we
 * store proxies as raw void* and call wl_proxy_destroy() only from our
 * explicit destructor.  Registry bindings use raw wl_registry_bind() rather
 * than Vala's wl_registry.bind<T>() so no temporary compact wrapper is
 * destroyed mid-callback.
 *
 * Config key: "background-blur" (bool, default false).
 * Requires compositor support (tested on niri).
 */
using Ext.BackgroundEffect;

[CCode (cname = "wl_compositor_interface", cheader_filename = "wayland-client-protocol.h")]
private extern Wl.Interface compositor_interface;

[CCode (cname = "wl_proxy_destroy", cheader_filename = "wayland-client.h")]
private extern void wl_proxy_destroy (void *proxy);

[CCode (cname = "wl_registry_bind", cheader_filename = "wayland-client.h")]
private extern void *wl_registry_bind (void *registry, uint32 name,
                                       ref Wl.Interface @interface,
                                       uint32 version);

[CCode (cname = "wl_registry_add_listener", cheader_filename = "wayland-client.h")]
private extern int wl_registry_add_listener (void *registry,
                                             Wl.RegistryListener listener,
                                             void *data);

[CCode (cname = "wl_region_destroy", cheader_filename = "wayland-client.h")]
private extern void wl_region_destroy (void *region);

[CCode (cname = "ext_background_effect_manager_v1_get_background_effect",
        cheader_filename = "ext-background-effect-v1-client-protocol.h")]
private extern Ext.BackgroundEffect.Surface *
bg_manager_get_bg_effect (void *manager, Wl.Surface surface);

[CCode (cname = "ext_background_effect_manager_v1_listener", has_type_id = false)]
private struct BgManagerListener {
    public BgManagerCapabilities capabilities;
}

[CCode (has_target = false, has_typedef = false)]
private extern delegate void BgManagerCapabilities (void *data, void *manager, uint32 flags);

[CCode (cname = "ext_background_effect_manager_v1_add_listener",
        cheader_filename = "ext-background-effect-v1-client-protocol.h")]
private extern int bg_manager_add_listener (void *manager,
                                            BgManagerListener listener,
                                            void *data);

[CCode (cname = "ext_background_effect_surface_v1_destroy",
        cheader_filename = "ext-background-effect-v1-client-protocol.h")]
private extern void bg_surface_destroy (Ext.BackgroundEffect.Surface *effect);

[CCode (cname = "ext_background_effect_surface_v1_set_blur_region",
        cheader_filename = "ext-background-effect-v1-client-protocol.h")]
private extern void bg_surface_set_blur_region (Ext.BackgroundEffect.Surface *effect, void *region);

[CCode (cheader_filename = "gtk/gtk.h")]
extern string gtk_style_context_to_string (Gtk.StyleContext ctx,
                                           Gtk.StyleContextPrintFlags flags);

[CCode (cname = "GTK_STYLE_CONTEXT_PRINT_SHOW_STYLE")]
private const int GTK_STYLE_CONTEXT_PRINT_SHOW_STYLE = 1 << 1;

namespace SwayNotificationCenter {
    public class BackgroundEffectHelper : Object {
        private const uint32 BG_CAPABILITY_BLUR = 1;

        /* Raw proxy pointers — Vala never wraps/auto-destroys them. */
        private void *manager_ptr = null;
        private void *compositor_ptr = null;
        private void *registry_ptr = null;

        public bool blur_available { get; private set; default = false; }

        public BackgroundEffectHelper () {
            Gdk.Display ?display = Gdk.Display.get_default ();
            if (display == null || !(display is Gdk.Wayland.Display)) {
                warning ("Not running on Wayland — background blur disabled.");
                return;
            }

            unowned Wl.Display wl_display =
                ((Gdk.Wayland.Display) display).get_wl_display ();

            registry_ptr = wl_display.get_registry ();
            wl_registry_add_listener (registry_ptr,
                                      build_registry_listener (), this);
            wl_display.roundtrip ();

            if (manager_ptr == null || compositor_ptr == null) {
                warning (
                    "ext-background-effect-v1 or wl_compositor not"
                    + " available — background blur disabled.");
                return;
            }

            if (!blur_available) {
                warning (
                    "ext-background-effect-v1 is available but blur is not"
                    + " advertised by the compositor.");
            }
        }

        ~BackgroundEffectHelper () {
            /* All fields are void* — no Vala free_function auto-call.
               Safe to destroy directly. */
            if (manager_ptr != null) {
                wl_proxy_destroy (manager_ptr);
                manager_ptr = null;
            }
            if (compositor_ptr != null) {
                wl_proxy_destroy (compositor_ptr);
                compositor_ptr = null;
            }
            if (registry_ptr != null) {
                wl_proxy_destroy (registry_ptr);
                registry_ptr = null;
            }
        }

        private Wl.RegistryListener build_registry_listener () {
            return Wl.RegistryListener () {
                       global = (data, wl_registry_void, name, iface, ver) => {
                           var helper = (BackgroundEffectHelper) data;
                           if (iface == "ext_background_effect_manager_v1") {
                               void *bound = wl_registry_bind (
                                   (void *) wl_registry_void,
                                   name, ref Manager.iface, 1);
                               helper.manager_ptr = bound;
                               bg_manager_add_listener (
                                   bound, build_manager_listener (), helper);
                           } else if (iface == "wl_compositor") {
                               uint32 bind_ver = ver >= 5 ? 5 : ver;
                               void *bound = wl_registry_bind (
                                   (void *) wl_registry_void,
                                   name, ref compositor_interface, bind_ver);
                               helper.compositor_ptr = bound;
                           }
                       },
            };
        }

        private static BgManagerListener build_manager_listener () {
            return BgManagerListener () {
                       capabilities = handle_capabilities,
            };
        }

        private static void handle_capabilities (void *data, void *manager,
                                                 uint32 flags) {
            var helper = (BackgroundEffectHelper) data;
            helper.blur_available = (flags & BG_CAPABILITY_BLUR) != 0;
        }

        public Surface *create_effect (Wl.Surface wl_surface) {
            if (!blur_available || manager_ptr == null
                || wl_surface == null) {
                return null;
            }
            return bg_manager_get_bg_effect (manager_ptr, wl_surface);
        }

        public void destroy_effect (Surface *effect) {
            if (effect != null) {
                bg_surface_destroy (effect);
            }
        }

        public void set_blur_region (Surface *effect,
                                     Cairo.Region ?cairo_region) {
            if (effect == null || compositor_ptr == null) {
                return;
            }

            if (cairo_region == null
                || cairo_region.num_rectangles () == 0) {
                bg_surface_set_blur_region (effect, null);
                return;
            }

            int n = cairo_region.num_rectangles ();
            void *region = wl_compositor_create_region (
                compositor_ptr);
            for (int i = 0; i < n; i++) {
                Cairo.RectangleInt r =
                    cairo_region.get_rectangle (i);
                wl_region_add (region,
                               r.x, r.y, r.width, r.height);
            }
            bg_surface_set_blur_region (effect, region);
            wl_region_destroy (region);
        }

        public void set_blur_region_rounded (Surface *effect,
                                             int x, int y,
                                             int w, int h,
                                             int radius) {
            if (effect == null || compositor_ptr == null
                || w <= 0 || h <= 0) {
                return;
            }

            void *region = wl_compositor_create_region (
                compositor_ptr);
            add_rounded_card (region, x, y, w, h, radius);
            bg_surface_set_blur_region (effect, region);
            wl_region_destroy (region);
        }

        public void set_blur_region_multi_rounded (Surface *effect,
                                                   int[] cards,
                                                   int radius) {
            if (effect == null || compositor_ptr == null
                || cards.length < 4) {
                return;
            }

            int n = cards.length / 4;
            void *region = wl_compositor_create_region (
                compositor_ptr);
            for (int i = 0; i < n; i++) {
                int off = i * 4;
                add_rounded_card (region,
                                  cards[off], cards[off + 1],
                                  cards[off + 2], cards[off + 3],
                                  radius);
            }
            bg_surface_set_blur_region (effect, region);
            wl_region_destroy (region);
        }

        private static void add_rounded_card (void *region,
                                              int x, int y,
                                              int w, int h,
                                              int radius) {
            if (w <= 0 || h <= 0) {
                return;
            }
            int r = int.min (radius, int.min (w / 2, h / 2));
            if (r <= 0) {
                wl_region_add (region, x, y, w, h);
                return;
            }
            for (int row = 0; row < r; row++) {
                int inset = (int) (r - Math.sqrt (
                                       r * r - (r - row) * (r - row)));
                int rw = w - 2 * inset;
                if (rw <= 0) {
                    continue;
                }
                wl_region_add (region,
                               x + inset, y + row, rw, 1);
                wl_region_add (region,
                               x + inset, y + h - 1 - row,
                               rw, 1);
            }
            int mid = h - 2 * r;
            if (mid > 0) {
                wl_region_add (region, x, y + r, w, mid);
            }
        }

        public static int get_widget_border_radius (Gtk.Widget widget) {
            if (widget == null) {
                return 0;
            }
            Gtk.StyleContext ?ctx = widget.get_style_context ();
            if (ctx == null) {
                return 0;
            }
            string str = gtk_style_context_to_string (
                ctx, (Gtk.StyleContextPrintFlags)
                GTK_STYLE_CONTEXT_PRINT_SHOW_STYLE);
            if (str == null || str.length == 0) {
                return 0;
            }
            int idx = str.index_of ("--border-radius:");
            if (idx < 0) {
                return 0;
            }
            string val = str.substring (
                idx + "--border-radius:".length).strip ();
            int64 parsed = 0;
            string digits = "";
            for (int i = 0; i < val.length; i++) {
                if (val[i].isdigit () || val[i] == '-') {
                    digits += val[i].to_string ();
                } else {
                    break;
                }
            }
            if (digits.length > 0
                && int64.try_parse (digits, out parsed)) {
                return (int) (parsed >= 0 ? parsed : 0);
            }
            return 0;
        }

        [CCode (cname = "wl_compositor_create_region",
                cheader_filename = "wayland-client.h")]
        private static extern void *wl_compositor_create_region (void *compositor);

        [CCode (cname = "wl_region_add",
                cheader_filename = "wayland-client.h")]
        private static extern void wl_region_add (void *region, int32 x, int32 y,
                                                  int32 width, int32 height);
    }
}
