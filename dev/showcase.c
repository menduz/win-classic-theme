/* A GTK3 window that holds one widget of each kind, for the screenshots of the
 * theme. `dev/screenshot.sh` starts it under Xvfb and Xfwm4, then takes the
 * picture.
 *
 * The program writes the file in READY_FILE when the windows are on the screen
 * and the first menu is open. The script waits for that file. Without
 * READY_FILE the program is a plain preview: it opens no menu and writes
 * nothing.
 */

#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>

static GtkWidget *menu_bar;
static GtkWidget *file_item;

/* Open the first menu, then tell the script that the picture is ready. */
static gboolean
on_settled (gpointer data)
{
  const char *path = g_getenv ("READY_FILE");
  FILE *file;

  if (path == NULL)
    return G_SOURCE_REMOVE;

  gtk_menu_shell_select_item (GTK_MENU_SHELL (menu_bar), file_item);

  file = fopen (path, "w");
  if (file == NULL)
    {
      g_printerr ("showcase: cannot write %s\n", path);
      return G_SOURCE_REMOVE;
    }
  fprintf (file, "ready\n");
  fclose (file);

  return G_SOURCE_REMOVE;
}

static GtkWidget *
menu_item (GtkWidget *menu, const char *label, const char *accel)
{
  GtkWidget *item = gtk_menu_item_new ();
  GtkWidget *box = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 24);
  GtkWidget *name = gtk_label_new_with_mnemonic (label);

  gtk_box_pack_start (GTK_BOX (box), name, FALSE, FALSE, 0);
  if (accel != NULL)
    {
      GtkWidget *key = gtk_label_new (accel);
      gtk_style_context_add_class (gtk_widget_get_style_context (key), "dim-label");
      gtk_box_pack_end (GTK_BOX (box), key, FALSE, FALSE, 0);
    }
  gtk_container_add (GTK_CONTAINER (item), box);
  gtk_menu_shell_append (GTK_MENU_SHELL (menu), item);

  return item;
}

/* The menu bar, with the items of the first menu. */
static GtkWidget *
build_menu_bar (void)
{
  GtkWidget *bar = gtk_menu_bar_new ();
  GtkWidget *menu = gtk_menu_new ();
  GtkWidget *item;
  const char *names[] = { "_Edit", "_View", "_Help" };
  guint i;

  file_item = gtk_menu_item_new_with_mnemonic ("_File");
  gtk_menu_item_set_submenu (GTK_MENU_ITEM (file_item), menu);
  gtk_menu_shell_append (GTK_MENU_SHELL (bar), file_item);

  menu_item (menu, "_New", "Ctrl+N");
  menu_item (menu, "_Open...", "Ctrl+O");
  menu_item (menu, "_Save", "Ctrl+S");
  gtk_menu_shell_append (GTK_MENU_SHELL (menu), gtk_separator_menu_item_new ());

  item = gtk_check_menu_item_new_with_mnemonic ("_Word Wrap");
  gtk_check_menu_item_set_active (GTK_CHECK_MENU_ITEM (item), TRUE);
  gtk_menu_shell_append (GTK_MENU_SHELL (menu), item);

  item = gtk_radio_menu_item_new_with_mnemonic (NULL, "_Small Icons");
  gtk_menu_shell_append (GTK_MENU_SHELL (menu), item);
  item = gtk_radio_menu_item_new_with_mnemonic_from_widget (GTK_RADIO_MENU_ITEM (item),
                                                            "_Large Icons");
  gtk_check_menu_item_set_active (GTK_CHECK_MENU_ITEM (item), TRUE);
  gtk_menu_shell_append (GTK_MENU_SHELL (menu), item);

  gtk_menu_shell_append (GTK_MENU_SHELL (menu), gtk_separator_menu_item_new ());
  item = menu_item (menu, "Page Set_up", NULL);
  gtk_widget_set_sensitive (item, FALSE);
  menu_item (menu, "_Close", "Alt+F4");

  for (i = 0; i < G_N_ELEMENTS (names); i++)
    gtk_menu_shell_append (GTK_MENU_SHELL (bar),
                           gtk_menu_item_new_with_mnemonic (names[i]));

  return bar;
}

static GtkWidget *
build_tool_bar (void)
{
  GtkWidget *bar = gtk_toolbar_new ();
  const char *icons[] = { "document-new", "document-open", "document-save" };
  const char *edits[] = { "edit-cut", "edit-copy", "edit-paste" };
  guint i;

  gtk_toolbar_set_style (GTK_TOOLBAR (bar), GTK_TOOLBAR_ICONS);

  for (i = 0; i < G_N_ELEMENTS (icons); i++)
    gtk_toolbar_insert (GTK_TOOLBAR (bar),
                        gtk_tool_button_new (gtk_image_new_from_icon_name (
                                                 icons[i], GTK_ICON_SIZE_LARGE_TOOLBAR),
                                             NULL),
                        -1);

  gtk_toolbar_insert (GTK_TOOLBAR (bar), gtk_separator_tool_item_new (), -1);

  for (i = 0; i < G_N_ELEMENTS (edits); i++)
    {
      GtkToolItem *item = gtk_tool_button_new (
          gtk_image_new_from_icon_name (edits[i], GTK_ICON_SIZE_LARGE_TOOLBAR), NULL);
      if (i == 2)
        gtk_widget_set_sensitive (GTK_WIDGET (item), FALSE);
      gtk_toolbar_insert (GTK_TOOLBAR (bar), item, -1);
    }

  return bar;
}

static GtkWidget *
frame_with (const char *title, GtkWidget *child)
{
  GtkWidget *frame = gtk_frame_new (title);

  gtk_container_set_border_width (GTK_CONTAINER (child), 8);
  gtk_container_add (GTK_CONTAINER (frame), child);

  return frame;
}

/* Check boxes, radio buttons and a switch, in two columns. */
static GtkWidget *
build_options (void)
{
  GtkWidget *box = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 16);
  GtkWidget *checks = gtk_box_new (GTK_ORIENTATION_VERTICAL, 4);
  GtkWidget *radios = gtk_box_new (GTK_ORIENTATION_VERTICAL, 4);
  GtkWidget *widget;
  GtkWidget *radio;

  widget = gtk_check_button_new_with_label ("Checked");
  gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (widget), TRUE);
  gtk_box_pack_start (GTK_BOX (checks), widget, FALSE, FALSE, 0);

  gtk_box_pack_start (GTK_BOX (checks), gtk_check_button_new_with_label ("Clear"), FALSE,
                      FALSE, 0);

  widget = gtk_check_button_new_with_label ("Disabled");
  gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (widget), TRUE);
  gtk_widget_set_sensitive (widget, FALSE);
  gtk_box_pack_start (GTK_BOX (checks), widget, FALSE, FALSE, 0);

  radio = gtk_radio_button_new_with_label (NULL, "First");
  gtk_box_pack_start (GTK_BOX (radios), radio, FALSE, FALSE, 0);
  widget = gtk_radio_button_new_with_label_from_widget (GTK_RADIO_BUTTON (radio), "Second");
  gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (widget), TRUE);
  gtk_box_pack_start (GTK_BOX (radios), widget, FALSE, FALSE, 0);

  widget = gtk_radio_button_new_with_label_from_widget (GTK_RADIO_BUTTON (radio), "Disabled");
  gtk_widget_set_sensitive (widget, FALSE);
  gtk_box_pack_start (GTK_BOX (radios), widget, FALSE, FALSE, 0);

  gtk_box_pack_start (GTK_BOX (box), checks, TRUE, TRUE, 0);
  gtk_box_pack_start (GTK_BOX (box), radios, TRUE, TRUE, 0);

  return frame_with ("Options", box);
}

/* The row of buttons at the foot of the window. The open menu never reaches
 * this far, so the buttons are in every picture. */
static GtkWidget *
build_buttons (void)
{
  GtkWidget *box = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 6);
  GtkWidget *widget;

  gtk_container_set_border_width (GTK_CONTAINER (box), 8);

  widget = gtk_button_new_with_label ("Disabled");
  gtk_widget_set_size_request (widget, 84, -1);
  gtk_widget_set_sensitive (widget, FALSE);
  gtk_box_pack_end (GTK_BOX (box), widget, FALSE, FALSE, 0);

  widget = gtk_toggle_button_new_with_label ("Pressed");
  gtk_widget_set_size_request (widget, 84, -1);
  gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (widget), TRUE);
  gtk_box_pack_end (GTK_BOX (box), widget, FALSE, FALSE, 0);

  widget = gtk_button_new_with_label ("Cancel");
  gtk_widget_set_size_request (widget, 84, -1);
  gtk_box_pack_end (GTK_BOX (box), widget, FALSE, FALSE, 0);

  widget = gtk_button_new_with_label ("OK");
  gtk_widget_set_size_request (widget, 84, -1);
  gtk_widget_set_can_default (widget, TRUE);
  gtk_box_pack_end (GTK_BOX (box), widget, FALSE, FALSE, 0);

  return box;
}

/* An entry, a combo box, a spin button, a scale and a progress bar. */
static GtkWidget *
build_inputs (void)
{
  GtkWidget *grid = gtk_grid_new ();
  GtkWidget *widget;

  gtk_grid_set_row_spacing (GTK_GRID (grid), 6);
  gtk_grid_set_column_spacing (GTK_GRID (grid), 8);

  gtk_grid_attach (GTK_GRID (grid), gtk_label_new ("Name"), 0, 0, 1, 1);
  widget = gtk_entry_new ();
  gtk_entry_set_text (GTK_ENTRY (widget), "Selected text");
  gtk_editable_select_region (GTK_EDITABLE (widget), 0, 8);
  gtk_widget_set_hexpand (widget, TRUE);
  gtk_grid_attach (GTK_GRID (grid), widget, 1, 0, 1, 1);

  gtk_grid_attach (GTK_GRID (grid), gtk_label_new ("Kind"), 0, 1, 1, 1);
  widget = gtk_combo_box_text_new ();
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Windows 95");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Windows 98");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Windows 2000");
  gtk_combo_box_set_active (GTK_COMBO_BOX (widget), 1);
  gtk_grid_attach (GTK_GRID (grid), widget, 1, 1, 1, 1);

  gtk_grid_attach (GTK_GRID (grid), gtk_label_new ("Count"), 0, 2, 1, 1);
  widget = gtk_spin_button_new_with_range (0, 100, 1);
  gtk_spin_button_set_value (GTK_SPIN_BUTTON (widget), 98);
  gtk_grid_attach (GTK_GRID (grid), widget, 1, 2, 1, 1);

  gtk_grid_attach (GTK_GRID (grid), gtk_label_new ("Level"), 0, 3, 1, 1);
  widget = gtk_scale_new_with_range (GTK_ORIENTATION_HORIZONTAL, 0, 100, 1);
  gtk_scale_set_draw_value (GTK_SCALE (widget), FALSE);
  gtk_range_set_value (GTK_RANGE (widget), 40);
  gtk_grid_attach (GTK_GRID (grid), widget, 1, 3, 1, 1);

  gtk_grid_attach (GTK_GRID (grid), gtk_label_new ("Copy"), 0, 4, 1, 1);
  widget = gtk_progress_bar_new ();
  gtk_progress_bar_set_fraction (GTK_PROGRESS_BAR (widget), 0.6);
  gtk_widget_set_valign (widget, GTK_ALIGN_CENTER);
  gtk_grid_attach (GTK_GRID (grid), widget, 1, 4, 1, 1);

  return frame_with ("Input", grid);
}

/* A list with one selected row, in a scrolled window. */
static GtkWidget *
build_list (void)
{
  GtkListStore *store = gtk_list_store_new (3, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_BOOLEAN);
  GtkWidget *view;
  GtkWidget *scrolled;
  GtkTreeSelection *selection;
  GtkTreeIter iter;
  GtkTreePath *path;
  guint i;
  const char *rows[][2] = {
    { "Autoexec.bat", "1 KB" },   { "Command.com", "93 KB" },
    { "Config.sys", "1 KB" },     { "Io.sys", "222 KB" },
    { "Msdos.sys", "1 KB" },      { "Scandisk.log", "3 KB" },
    { "Suhdlog.dat", "5 KB" },    { "System.1st", "1,624 KB" },
  };

  for (i = 0; i < G_N_ELEMENTS (rows); i++)
    {
      gtk_list_store_append (store, &iter);
      gtk_list_store_set (store, &iter, 0, rows[i][0], 1, rows[i][1], 2, i % 3 == 0, -1);
    }

  view = gtk_tree_view_new_with_model (GTK_TREE_MODEL (store));
  g_object_unref (store);

  gtk_tree_view_insert_column_with_attributes (
      GTK_TREE_VIEW (view), -1, "Read only", gtk_cell_renderer_toggle_new (), "active", 2, NULL);
  gtk_tree_view_insert_column_with_attributes (
      GTK_TREE_VIEW (view), -1, "Name", gtk_cell_renderer_text_new (), "text", 0, NULL);
  gtk_tree_view_insert_column_with_attributes (
      GTK_TREE_VIEW (view), -1, "Size", gtk_cell_renderer_text_new (), "text", 1, NULL);

  selection = gtk_tree_view_get_selection (GTK_TREE_VIEW (view));
  path = gtk_tree_path_new_from_indices (2, -1);
  gtk_tree_selection_select_path (selection, path);
  gtk_tree_path_free (path);

  scrolled = gtk_scrolled_window_new (NULL, NULL);
  gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (scrolled), GTK_POLICY_AUTOMATIC,
                                  GTK_POLICY_ALWAYS);
  gtk_scrolled_window_set_shadow_type (GTK_SCROLLED_WINDOW (scrolled), GTK_SHADOW_IN);
  gtk_container_add (GTK_CONTAINER (scrolled), view);
  gtk_widget_set_size_request (scrolled, 300, -1);

  return scrolled;
}

/* A text box with a selection, in a scrolled window. */
static GtkWidget *
build_text (void)
{
  GtkWidget *view = gtk_text_view_new ();
  GtkWidget *scrolled = gtk_scrolled_window_new (NULL, NULL);
  GtkTextBuffer *buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (view));
  GtkTextIter start, end;

  gtk_text_buffer_set_text (
      buffer,
      "The theme paints every image from the colors of the scheme.\n"
      "The scheme holds the system colors of Windows: the face color,\n"
      "the title bar, the highlight and the two 3D edges.\n\n"
      "This text box shows the window color and the selection.\n",
      -1);

  gtk_text_buffer_get_iter_at_offset (buffer, &start, 145);
  gtk_text_buffer_get_iter_at_offset (buffer, &end, 176);
  gtk_text_buffer_select_range (buffer, &end, &start);

  gtk_text_view_set_left_margin (GTK_TEXT_VIEW (view), 4);
  gtk_text_view_set_top_margin (GTK_TEXT_VIEW (view), 2);
  gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (scrolled), GTK_POLICY_AUTOMATIC,
                                  GTK_POLICY_ALWAYS);
  gtk_scrolled_window_set_shadow_type (GTK_SCROLLED_WINDOW (scrolled), GTK_SHADOW_IN);
  gtk_container_add (GTK_CONTAINER (scrolled), view);
  gtk_widget_set_size_request (scrolled, -1, 150);

  return scrolled;
}

static GtkWidget *
build_note_book (void)
{
  GtkWidget *book = gtk_notebook_new ();
  GtkWidget *page = gtk_box_new (GTK_ORIENTATION_VERTICAL, 8);

  gtk_container_set_border_width (GTK_CONTAINER (page), 8);
  gtk_box_pack_start (GTK_BOX (page), build_options (), FALSE, FALSE, 0);
  gtk_box_pack_start (GTK_BOX (page), build_inputs (), FALSE, FALSE, 0);
  gtk_notebook_append_page (GTK_NOTEBOOK (book), page, gtk_label_new ("Widgets"));

  gtk_notebook_append_page (GTK_NOTEBOOK (book), build_text (), gtk_label_new ("Text"));

  return book;
}

/* The small window behind the main one. It shows the inactive title bar. */
static GtkWidget *
build_dialog (void)
{
  GtkWidget *window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
  GtkWidget *box = gtk_box_new (GTK_ORIENTATION_VERTICAL, 12);
  GtkWidget *row = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 12);
  GtkWidget *buttons = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 8);
  GtkWidget *label = gtk_label_new ("The window behind holds the colors\nof the inactive title bar.");
  GtkWidget *button;

  gtk_window_set_title (GTK_WINDOW (window), "Inactive Window");
  gtk_container_set_border_width (GTK_CONTAINER (box), 12);
  gtk_label_set_xalign (GTK_LABEL (label), 0.0);

  gtk_box_pack_start (GTK_BOX (row),
                      gtk_image_new_from_icon_name ("dialog-information", GTK_ICON_SIZE_DIALOG),
                      FALSE, FALSE, 0);
  gtk_box_pack_start (GTK_BOX (row), label, TRUE, TRUE, 0);

  button = gtk_button_new_with_label ("OK");
  gtk_widget_set_size_request (button, 80, -1);
  gtk_box_pack_end (GTK_BOX (buttons), button, FALSE, FALSE, 0);
  button = gtk_button_new_with_label ("Cancel");
  gtk_widget_set_size_request (button, 80, -1);
  gtk_box_pack_end (GTK_BOX (buttons), button, FALSE, FALSE, 0);

  gtk_box_pack_start (GTK_BOX (box), row, TRUE, TRUE, 0);
  gtk_box_pack_start (GTK_BOX (box), gtk_separator_new (GTK_ORIENTATION_HORIZONTAL), FALSE,
                      FALSE, 0);
  gtk_box_pack_start (GTK_BOX (box), buttons, FALSE, FALSE, 0);
  gtk_container_add (GTK_CONTAINER (window), box);

  return window;
}

int
main (int argc, char **argv)
{
  GtkWidget *window;
  GtkWidget *box;
  GtkWidget *panes;
  GtkWidget *right;
  GtkWidget *status;
  GtkWidget *dialog;
  const char *title = g_getenv ("SHOWCASE_TITLE");

  gtk_init (&argc, &argv);

  window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
  gtk_window_set_title (GTK_WINDOW (window), title != NULL ? title : "Win Classic Theme");
  /* A little more than the widgets ask for, to keep space around them. */
  gtk_window_set_default_size (GTK_WINDOW (window), 720, 530);
  g_signal_connect (window, "destroy", G_CALLBACK (gtk_main_quit), NULL);

  /* The menu of the picture opens below the left corner and covers the list.
   * The tool bar and the note book are on the right, where nothing hides
   * them, and the buttons are at the foot. */
  right = gtk_box_new (GTK_ORIENTATION_VERTICAL, 8);
  gtk_box_pack_start (GTK_BOX (right), build_tool_bar (), FALSE, FALSE, 0);
  gtk_box_pack_start (GTK_BOX (right), build_note_book (), TRUE, TRUE, 0);

  panes = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 8);
  gtk_container_set_border_width (GTK_CONTAINER (panes), 8);
  gtk_box_pack_start (GTK_BOX (panes), build_list (), FALSE, TRUE, 0);
  gtk_box_pack_start (GTK_BOX (panes), right, TRUE, TRUE, 0);

  menu_bar = build_menu_bar ();
  box = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
  gtk_box_pack_start (GTK_BOX (box), menu_bar, FALSE, FALSE, 0);
  gtk_box_pack_start (GTK_BOX (box), panes, TRUE, TRUE, 0);
  gtk_box_pack_start (GTK_BOX (box), build_buttons (), FALSE, FALSE, 0);

  status = gtk_statusbar_new ();
  gtk_statusbar_push (GTK_STATUSBAR (status),
                      gtk_statusbar_get_context_id (GTK_STATUSBAR (status), "main"),
                      "8 objects");
  gtk_box_pack_end (GTK_BOX (box), status, FALSE, FALSE, 0);
  gtk_container_add (GTK_CONTAINER (window), box);

  /* The second window is above and on the left, so that the main window
   * covers a part of it and leaves its title bar in view. */
  dialog = build_dialog ();
  gtk_widget_show_all (dialog);
  gtk_window_move (GTK_WINDOW (dialog), 28, 26);

  gtk_widget_show_all (window);
  gtk_window_move (GTK_WINDOW (window), 150, 120);
  gtk_window_present (GTK_WINDOW (window));

  /* Wait for the window manager to put the frames on the windows. */
  g_timeout_add (1200, on_settled, NULL);

  gtk_main ();

  return 0;
}
