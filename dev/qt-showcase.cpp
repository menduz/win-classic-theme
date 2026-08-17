/* A Qt window that holds common widgets for the screenshots of the theme. */

#include <QAction>
#include <QApplication>
#include <QCheckBox>
#include <QComboBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QGroupBox>
#include <QHBoxLayout>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMainWindow>
#include <QMenu>
#include <QMenuBar>
#include <QProgressBar>
#include <QPushButton>
#include <QRadioButton>
#include <QSlider>
#include <QSpinBox>
#include <QSplitter>
#include <QStatusBar>
#include <QTabWidget>
#include <QTableWidget>
#include <QTextCursor>
#include <QTextEdit>
#include <QToolBar>
#include <QTreeWidget>
#include <QVBoxLayout>

static QGroupBox *
make_buttons ()
{
  auto *group = new QGroupBox ("Buttons");
  auto *layout = new QVBoxLayout (group);
  auto *normal = new QPushButton ("Normal");
  auto *pressed = new QPushButton ("Pressed");
  auto *disabled = new QPushButton ("Disabled");
  auto *checked = new QCheckBox ("Checked");
  auto *unchecked = new QCheckBox ("Unchecked");
  auto *mixed = new QCheckBox ("Mixed");
  auto *radio_one = new QRadioButton ("First");
  auto *radio_two = new QRadioButton ("Second");

  normal->setDefault (true);
  pressed->setCheckable (true);
  pressed->setChecked (true);
  disabled->setEnabled (false);
  checked->setChecked (true);
  mixed->setTristate (true);
  mixed->setCheckState (Qt::PartiallyChecked);
  radio_two->setChecked (true);

  layout->addWidget (normal);
  layout->addWidget (pressed);
  layout->addWidget (disabled);
  layout->addSpacing (8);
  layout->addWidget (checked);
  layout->addWidget (unchecked);
  layout->addWidget (mixed);
  layout->addSpacing (8);
  layout->addWidget (radio_one);
  layout->addWidget (radio_two);
  layout->addStretch (1);
  return group;
}

static QGroupBox *
make_values ()
{
  auto *group = new QGroupBox ("Values");
  auto *layout = new QFormLayout (group);
  auto *entry = new QLineEdit ("Selected text");
  auto *combo = new QComboBox;
  auto *spin = new QSpinBox;
  auto *slider = new QSlider (Qt::Horizontal);
  auto *progress = new QProgressBar;

  entry->setSelection (0, 8);
  combo->addItems ({ "Windows 95", "Windows 98", "Windows 2000" });
  combo->setCurrentIndex (1);
  spin->setRange (0, 100);
  spin->setValue (98);
  slider->setRange (0, 100);
  slider->setValue (40);
  slider->setTickPosition (QSlider::TicksBelow);
  progress->setRange (0, 100);
  progress->setValue (60);

  layout->addRow ("Text:", entry);
  layout->addRow ("Choice:", combo);
  layout->addRow ("Number:", spin);
  layout->addRow ("Position:", slider);
  layout->addRow ("Progress:", progress);
  return group;
}

static QWidget *
make_lists ()
{
  auto *tabs = new QTabWidget;
  auto *tree = new QTreeWidget;
  auto *table = new QTableWidget (4, 3);
  auto *text = new QTextEdit;

  tree->setHeaderLabels ({ "Name", "Type", "Size" });
  auto *documents = new QTreeWidgetItem (tree, { "Documents", "Folder", "" });
  new QTreeWidgetItem (documents, { "Notes.txt", "Text file", "4 KB" });
  new QTreeWidgetItem (documents, { "Report.txt", "Text file", "12 KB" });
  new QTreeWidgetItem (tree, { "Pictures", "Folder", "" });
  documents->setExpanded (true);
  tree->setCurrentItem (documents->child (0));

  table->setHorizontalHeaderLabels ({ "Name", "Status", "Value" });
  table->setVerticalHeaderLabels ({ "One", "Two", "Three", "Four" });
  for (int row = 0; row < table->rowCount (); row++)
    {
      table->setItem (row, 0, new QTableWidgetItem (QString ("Item %1").arg (row + 1)));
      table->setItem (row, 1, new QTableWidgetItem (row == 1 ? "Disabled" : "Ready"));
      table->setItem (row, 2, new QTableWidgetItem (QString::number ((row + 1) * 10)));
    }
  table->setCurrentCell (1, 0);

  text->setPlainText (
    "Qt renders these widgets through the GTK2 bridge.\n\n"
    "This text area shows selection, scroll bars and the input frame.");
  text->moveCursor (QTextCursor::Start);
  text->moveCursor (QTextCursor::NextWord, QTextCursor::KeepAnchor);

  tabs->addTab (tree, "Tree");
  tabs->addTab (table, "Table");
  tabs->addTab (text, "Text");
  return tabs;
}

static QWidget *
make_center ()
{
  auto *center = new QWidget;
  auto *layout = new QVBoxLayout (center);
  auto *splitter = new QSplitter;
  auto *controls = new QWidget;
  auto *controls_layout = new QHBoxLayout (controls);
  auto *buttons = new QDialogButtonBox (
    QDialogButtonBox::Ok | QDialogButtonBox::Cancel | QDialogButtonBox::Apply);

  controls_layout->setContentsMargins (0, 0, 0, 0);
  controls_layout->addWidget (make_buttons ());
  controls_layout->addWidget (make_values ());
  splitter->addWidget (controls);
  splitter->addWidget (make_lists ());
  splitter->setStretchFactor (0, 2);
  splitter->setStretchFactor (1, 3);

  layout->addWidget (splitter, 1);
  layout->addWidget (buttons);
  return center;
}

static void
make_menus (QMainWindow *window)
{
  auto *file = window->menuBar ()->addMenu ("&File");
  auto *edit = window->menuBar ()->addMenu ("&Edit");
  auto *view = window->menuBar ()->addMenu ("&View");
  auto *help = window->menuBar ()->addMenu ("&Help");

  file->addAction ("&New");
  file->addAction ("&Open...");
  file->addAction ("&Save");
  file->addSeparator ();
  file->addAction ("E&xit");
  edit->addAction ("Cu&t");
  edit->addAction ("&Copy");
  edit->addAction ("&Paste");
  view->addAction ("&Toolbar")->setCheckable (true);
  help->addAction ("&About");
}

static void
make_toolbar (QMainWindow *window)
{
  auto *toolbar = window->addToolBar ("Main");

  toolbar->addAction ("New");
  toolbar->addAction ("Open");
  toolbar->addAction ("Save");
  toolbar->addSeparator ();
  toolbar->addAction ("Cut");
  toolbar->addAction ("Copy");
  toolbar->addAction ("Paste");
}

int
main (int argc, char **argv)
{
  QApplication application (argc, argv);
  QMainWindow window;

  application.setApplicationDisplayName ("Qt widget showcase");
  window.setWindowTitle ("Qt widget showcase");
  window.setCentralWidget (make_center ());
  make_menus (&window);
  make_toolbar (&window);
  window.statusBar ()->showMessage ("Ready");
  window.statusBar ()->addPermanentWidget (new QLabel (QString ("Qt %1").arg (qVersion ())));
  window.resize (900, 560);
  window.show ();
  return application.exec ();
}
