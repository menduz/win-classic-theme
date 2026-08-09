/* Read a style sheet with the parser of GTK and report what it does not
 * understand.
 *
 *     check-css [--ignore-unknown-property] <file>
 *
 * The program ends with 1 when the parser reports an error. `dev/checks.nix`
 * builds it two times, one time with GTK3 and one time with GTK4.
 *
 * GTK4 reads the style sheet of GTK3, which holds the style properties of
 * GTK3. GTK4 knows none of them and reports each one. The flag
 * `--ignore-unknown-property` lets those pass.
 */

#include <gtk/gtk.h>
#include <stdio.h>
#include <string.h>

static int errors = 0;
static gboolean ignore_unknown_property = FALSE;

static void
on_parsing_error (GtkCssProvider *provider,
                  GtkCssSection *section,
                  const GError *error,
                  gpointer data)
{
  char *where;

  if (ignore_unknown_property && strstr (error->message, "No property named") != NULL)
    return;

#if GTK_MAJOR_VERSION >= 4
  where = gtk_css_section_to_string (section);
#else
  where = g_strdup_printf ("%s:%u",
                           gtk_css_section_get_file (section)
                             ? g_file_get_path (gtk_css_section_get_file (section))
                             : "<data>",
                           gtk_css_section_get_start_line (section) + 1);
#endif

  g_printerr ("%s: %s\n", where, error->message);
  g_free (where);
  errors++;
}

int
main (int argc, char **argv)
{
  GtkCssProvider *provider;
  const char *path = NULL;
  int i;

  for (i = 1; i < argc; i++)
    {
      if (g_str_equal (argv[i], "--ignore-unknown-property"))
        ignore_unknown_property = TRUE;
      else
        path = argv[i];
    }

  if (path == NULL)
    {
      g_printerr ("usage: check-css [--ignore-unknown-property] <file>\n");
      return 2;
    }

  provider = gtk_css_provider_new ();
  g_signal_connect (provider, "parsing-error", G_CALLBACK (on_parsing_error), NULL);

#if GTK_MAJOR_VERSION >= 4
  gtk_css_provider_load_from_path (provider, path);
#else
  gtk_css_provider_load_from_path (provider, path, NULL);
#endif

  if (errors > 0)
    {
      g_printerr ("check-css: %s holds %d error(s) for GTK%d\n",
                  path, errors, GTK_MAJOR_VERSION);
      return 1;
    }

  g_print ("check-css: GTK%d reads %s\n", GTK_MAJOR_VERSION, path);

  return 0;
}
