/* Print the colors that Chromium and Brave read from the GTK3 theme.
 *
 *     chromium-colors
 *
 * Chromium does not read a palette. It makes a chain of CSS nodes for each
 * color, draws the background or the frame of the chain into a surface of
 * 24x24 pixels and takes the average of the pixels. This program does the same
 * steps as ui/gtk/gtk_util.cc of Chromium 153. It reads the theme of
 * GTK_THEME, or else the theme of the GTK settings.
 *
 * Chromium adds the class "chromium" to each node. A rule with this class
 * applies only to Chromium.
 *
 * The names in the output are the names of the color IDs in
 * ui/gtk/gtk_color_mixers.cc and in GtkUi::LoadGtkValues of ui/gtk/gtk_ui.cc.
 * Brave uses these colors when brave://settings/appearance selects "GTK".
 */

#include <gtk/gtk.h>
#include <stdio.h>
#include <string.h>

typedef guint32 Color; /* 0xAARRGGBB, as SkColor */

#define A(c) (((c) >> 24) & 0xff)
#define R(c) (((c) >> 16) & 0xff)
#define G(c) (((c) >> 8) & 0xff)
#define B(c) ((c) & 0xff)
#define ARGB(a, r, g, b) \
  (((Color) (a) << 24) | ((Color) (r) << 16) | ((Color) (g) << 8) | (Color) (b))

static Color
from_rgba (const GdkRGBA *c)
{
  return ARGB ((int) (c->alpha * 255 + 0.5), (int) (c->red * 255 + 0.5),
               (int) (c->green * 255 + 0.5), (int) (c->blue * 255 + 0.5));
}

/* color_utils::AlphaBlend and GetResultingPaintColor of Chromium. */
static Color
paint_over (Color fg, Color bg)
{
  int a = A (fg);
  if (a == 0)
    return bg;
  if (a == 255)
    return fg;
  int ba = A (bg);
  double f = a / 255.0;
  double out_a = a + ba * (1 - f);
  if (out_a == 0)
    return 0;
  int r = (int) ((R (fg) * a + R (bg) * ba * (1 - f)) / out_a + 0.5);
  int g = (int) ((G (fg) * a + G (bg) * ba * (1 - f)) / out_a + 0.5);
  int b = (int) ((B (fg) * a + B (bg) * ba * (1 - f)) / out_a + 0.5);
  return ARGB ((int) (out_a + 0.5), r, g, b);
}

/* AppendCssNodeToStyleContext: "name(widget-name).class:pseudo". */
static GtkStyleContext *
append_node (GtkStyleContext *parent, const char *node)
{
  static const struct
  {
    const char *name;
    GtkStateFlags flag;
  } pseudo[] = {
    { "active", GTK_STATE_FLAG_ACTIVE },
    { "hover", GTK_STATE_FLAG_PRELIGHT },
    { "selected", GTK_STATE_FLAG_SELECTED },
    { "disabled", GTK_STATE_FLAG_INSENSITIVE },
    { "indeterminate", GTK_STATE_FLAG_INCONSISTENT },
    { "focus", GTK_STATE_FLAG_FOCUSED },
    { "backdrop", GTK_STATE_FLAG_BACKDROP },
    { "link", GTK_STATE_FLAG_LINK },
    { "visited", GTK_STATE_FLAG_VISITED },
    { "checked", GTK_STATE_FLAG_CHECKED },
    /* "focus-within" is a GTK4 state. Chromium ignores it on GTK3. */
  };
  GtkWidgetPath *path = parent
                          ? gtk_widget_path_copy (gtk_style_context_get_path (parent))
                          : gtk_widget_path_new ();
  GtkStateFlags state = GTK_STATE_FLAG_NORMAL;
  char kind = 'o';
  const char *p = node;

  gtk_widget_path_append_type (path, G_TYPE_NONE);
  while (*p)
    {
      size_t n = strcspn (p, ".:()");
      char *tok = g_strndup (p, n);
      if (n > 0)
        switch (kind)
          {
          case 'o':
            gtk_widget_path_iter_set_object_name (path, -1, tok);
            break;
          case 'n':
            gtk_widget_path_iter_set_name (path, -1, tok);
            break;
          case '.':
            gtk_widget_path_iter_add_class (path, -1, tok);
            break;
          case ':':
            for (size_t i = 0; i < G_N_ELEMENTS (pseudo); i++)
              if (g_str_equal (pseudo[i].name, tok))
                state |= pseudo[i].flag;
            break;
          }
      g_free (tok);
      p += n;
      if (!*p)
        break;
      kind = *p == '(' ? 'n' : *p == ')' ? 'x' : *p;
      p++;
    }
  gtk_widget_path_iter_add_class (path, -1, "chromium");
  gtk_widget_path_iter_set_state (path, -1, state);

  GtkStyleContext *ctx = gtk_style_context_new ();
  gtk_style_context_set_path (ctx, path);
  gtk_style_context_set_state (ctx, state);
  gtk_style_context_set_scale (ctx, 1);
  gtk_style_context_set_parent (ctx, parent);
  gtk_widget_path_unref (path);
  return ctx;
}

/* GetStyleContextFromCss: a "window.background" node, then each node. */
static GtkStyleContext *
context_from_css (const char *selector)
{
  GtkStyleContext *ctx = append_node (NULL, "window.background");
  char **nodes = g_strsplit_set (selector, " ", -1);
  for (char **n = nodes; *n; n++)
    if (**n)
      ctx = append_node (ctx, *n);
  g_strfreev (nodes);
  return ctx;
}

/* CairoSurface::GetAveragePixelValue. */
static Color
average (cairo_surface_t *s, gboolean frame)
{
  cairo_surface_flush (s);
  const guint32 *data = (const guint32 *) cairo_image_surface_get_data (s);
  int count = cairo_image_surface_get_width (s) * cairo_image_surface_get_height (s);
  long a = 0, r = 0, g = 0, b = 0;
  unsigned max_a = 0;
  for (int i = 0; i < count; i++)
    {
      Color c = data[i];
      max_a = MAX (A (c), max_a);
      a += A (c);
      r += R (c);
      g += G (c);
      b += B (c);
    }
  if (a == 0)
    return 0;
  return ARGB (frame ? max_a : a / count, r * 255 / a, g * 255 / a, b * 255 / a);
}

static void
render_background (cairo_t *cr, GtkStyleContext *ctx)
{
  if (!ctx)
    return;
  render_background (cr, gtk_style_context_get_parent (ctx));
  gtk_render_background (ctx, cr, 0, 0, 24, 24);
}

/* GetBgColorFromStyleContext. */
static Color
bg_of_context (GtkStyleContext *ctx)
{
  GtkCssProvider *provider = gtk_css_provider_new ();
  gtk_css_provider_load_from_data (provider,
                                   "* { border-radius: 0px; border-style: none;"
                                   " box-shadow: none; }",
                                   -1, NULL);
  for (GtkStyleContext *c = ctx; c; c = gtk_style_context_get_parent (c))
    gtk_style_context_add_provider (c, GTK_STYLE_PROVIDER (provider), G_MAXUINT);
  g_object_unref (provider);

  cairo_surface_t *s = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, 24, 24);
  cairo_t *cr = cairo_create (s);
  render_background (cr, ctx);
  cairo_destroy (cr);
  Color c = average (s, FALSE);
  cairo_surface_destroy (s);
  return c;
}

static Color
bg (const char *selector)
{
  return bg_of_context (context_from_css (selector));
}

static Color
fg (const char *selector)
{
  GtkStyleContext *ctx = context_from_css (selector);
  GdkRGBA rgba;
  gtk_style_context_get_color (ctx, gtk_style_context_get_state (ctx), &rgba);
  Color c = from_rgba (&rgba);
  return A (c) == 255 ? c : paint_over (c, bg_of_context (ctx));
}

static Color
border (const char *selector)
{
  GtkStyleContext *ctx = context_from_css (selector);
  cairo_surface_t *s = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, 24, 24);
  cairo_t *cr = cairo_create (s);
  gtk_render_frame (ctx, cr, 0, 0, 24, 24);
  cairo_destroy (cr);
  Color c = average (s, TRUE);
  cairo_surface_destroy (s);
  return A (c) == 255 ? c : paint_over (c, bg_of_context (ctx));
}

static void
put (const char *id, Color c, const char *source)
{
  if (A (c) == 255)
    printf ("%-46s #%02x%02x%02x    %s\n", id, R (c), G (c), B (c), source);
  else
    printf ("%-46s #%02x%02x%02x%02x  %s\n", id, R (c), G (c), B (c), A (c), source);
}

#define BG(id, sel) put (id, bg (sel), "bg     " sel)
#define FG(id, sel) put (id, fg (sel), "fg     " sel)
#define BORDER(id, sel) put (id, border (sel), "border " sel)

int
main (int argc, char **argv)
{
  gtk_init (&argc, &argv);

  /* GtkUi::LoadGtkValues writes these values in the ThemeProperties of the
   * system theme. They have priority over the color mixers below. */
  printf ("== ThemeProperties (gtk_ui.cc LoadGtkValues)\n");
  for (int custom = 0; custom <= 1; custom++)
    {
      const char *h = custom ? "headerbar.header-bar.titlebar" : "menubar";
      char sel[256];
      printf ("-- %s frame: header node \"%s\"\n",
              custom ? "Chromium (custom)" : "system", h);
      Color frame = bg (h) | 0xff000000;
      g_snprintf (sel, sizeof sel, "%s:backdrop", h);
      Color frame_inactive = bg (sel) | 0xff000000;
      put ("COLOR_FRAME_ACTIVE", frame, "bg     <header>");
      put ("COLOR_FRAME_INACTIVE", frame_inactive, "bg     <header>:backdrop");
      put ("COLOR_TOOLBAR, COLOR_TAB_BACKGROUND_ACTIVE_*", paint_over (bg (""), frame),
           "bg     window.background, over the frame");
      g_snprintf (sel, sizeof sel, "%s label.title", h);
      put ("COLOR_TAB_FOREGROUND_INACTIVE_FRAME_ACTIVE", fg (sel), "fg     <header> label.title");
      g_snprintf (sel, sizeof sel, "%s:backdrop label.title", h);
      put ("COLOR_TAB_FOREGROUND_INACTIVE_FRAME_INACTIVE", fg (sel),
           "fg     <header>:backdrop label.title");
      g_snprintf (sel, sizeof sel, "%s separator.vertical.titlebutton", h);
      put ("COLOR_TAB_STROKE_FRAME_ACTIVE (1st choice)", border (sel),
           "border <header> separator.vertical.titlebutton");
      g_snprintf (sel, sizeof sel, "%s button", h);
      put ("COLOR_TAB_STROKE_FRAME_ACTIVE (2nd choice)", border (sel),
           "border <header> button");
    }
  printf ("-- both frames\n");
  BORDER ("COLOR_LOCATION_BAR_BORDER", "entry");
  BORDER ("COLOR_TOOLBAR_CONTENT_AREA_SEPARATOR", "button");
  FG ("COLOR_TOOLBAR_TEXT, COLOR_TOOLBAR_BUTTON_ICON", "label");

  printf ("\n== Color mixer (gtk_color_mixers.cc)\n");
  BG ("kColorPrimaryBackground", "");
  FG ("kColorPrimaryForeground", "label");
  FG ("kColorDisabledForeground", "label:disabled");
  BG ("kColorAccent", "treeview.view treeview.view.cell:selected:focus");
  FG ("kColorButtonForegroundProminent", "treeview.view treeview.view.cell:selected:focus label");
  BG ("kColorTextSelectionBackground", "textview.view:focus text:focus selection:focus");
  FG ("kColorTextSelectionForeground", "textview.view:focus text:focus selection:focus");
  BG ("kColorTextfieldBackground (omnibox, NTP)", "textview.view");
  FG ("kColorTextfieldForeground (omnibox text)", "textview.view text");
  BORDER ("kColorFocusableBorderUnfocused", "entry");
  BORDER ("kColorItemHighlight (focus ring)", "entry:focus");
  BG ("kColorButtonBackground", "button");
  BORDER ("kColorButtonBorder", "button");
  FG ("kColorButtonForeground", "button.text-button label");
  BG ("kColorMenuBackground", "menu");
  BORDER ("kColorMenuBorder", "menu");
  FG ("kColorMenuItemForeground", "menu menuitem label");
  BG ("kColorMenuSelectionBackground", "menu menuitem:hover");
  FG ("kColorMenuItemForegroundSelected", "menu menuitem:hover label");
  FG ("kColorMenuItemForegroundDisabled", "menu menuitem:disabled label");
  FG ("kColorMenuItemForegroundSecondary", "menu menuitem accelerator");
  BORDER ("kColorNativeBoxFrameBorder (toolbar separator)", "box.frame");
  FG ("kColorIcon", "button.flat.scale image");
  FG ("kColorLinkForegroundDefault", "label.link:link");
  BG ("kColorTabBackgroundHighlighted", "notebook tab:checked");
  BORDER ("kColorTabContentSeparator", "frame border");
  BG ("kColorTreeBackground", "treeview.view treeview.view.cell");
  BG ("kColorTreeNodeBackgroundSelectedUnfocused", "treeview.view treeview.view.cell:selected");
  BG ("kColorTableHeaderBackground", "treeview.view button");
  BG ("kColorOverlayScrollbarFill", "scrollbar slider");
  BG ("kColorOverlayScrollbarStroke", "scrollbar trough");
  BG ("kColorSliderTrack", "scale trough");
  BG ("kColorToggleButtonTrackOn", "button.text-button.toggle:checked");
  FG ("kColorThrobber", "spinner");

  GtkStyleContext *tip = append_node (NULL, "tooltip.background");
  put ("kColorTooltipBackground", bg_of_context (tip), "bg     tooltip.background");
  GdkRGBA rgba;
  GtkStyleContext *tip_label = append_node (tip, "label");
  gtk_style_context_get_color (tip_label, gtk_style_context_get_state (tip_label), &rgba);
  put ("kColorTooltipForeground", from_rgba (&rgba), "fg     tooltip.background label");
  return 0;
}
