{
  libsForQt5,
  qt6Packages,
}:
{
  qt5 = libsForQt5.qtstyleplugins.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./qt5gtk2.patch ];
  });

  qt6 = qt6Packages.qt6gtk2.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./qt6gtk2.patch ];
  });
}
