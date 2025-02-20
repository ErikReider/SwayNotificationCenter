#include <gdk/gdk.h>
#include <gdk/gdkwayland.h>
#include <glib.h>
#include <stdio.h>
#include <wayland-client.h>

/** GDK doesn't provide a vapi file for GDK Wayland... */

#define PRINT_ERROR                                                            \
	g_error("Gdk Display isn't a Wayland display! Only Wayland is supported")

struct wl_display *get_wl_display() {
	GdkDisplay *display = gdk_display_get_default();
	if (GDK_IS_WAYLAND_DISPLAY(display)) {
		return gdk_wayland_display_get_wl_display(display);
	}
	PRINT_ERROR;
	return NULL;
}

struct wl_surface *get_wl_surface(GdkWindow *window) {
	if (GDK_IS_WAYLAND_WINDOW(window)) {
		return gdk_wayland_window_get_wl_surface(window);
	}
	PRINT_ERROR;
	return NULL;
}
