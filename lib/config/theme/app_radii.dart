/// Corner-radius scale. Radius rises with an element's importance, not its
/// size: controls 12, cards 22, lifted surfaces 24, chips and tags pill.
/// Nested corners step down by at least 4 so they don't collide optically.
abstract final class AppRadii {
  static const double sm = 12;
  static const double card = 22;
  static const double lg = 24;
  static const double groupedList = 22;
  static const double pill = 9999;

  const AppRadii._();
}
