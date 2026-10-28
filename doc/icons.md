# Icons

How the panel's icons are drawn, sized, and aligned with text.

## Drawing

- Each icon is a QML `Shape` on a 24-unit grid: `SwordIcon.qml` (quest),
  `FlagIcon.qml` (realm), `GlobeIcon.qml` (world). Its source art is in
  `assets/*.svg`, and the QML copies the path data. Change both together.
- Icons are filled shapes with no strokes, in one color set by `color`.

## Sizing

There are two ways to size an icon, both in `Questmarchy.qml`:

- `GridIcon` scales the whole 24-unit grid to a box of `size × 1.25`, so the
  grid's margin makes the icon look as large as a glyph of `size`. Used for
  standalone icons: the icon at each row's right end (0.8 of
  `Style.font.title`) and the tab icons (`Style.font.heading`).
- `FittedIcon` scales the icon's outline (`Shape.boundingRect`) to its
  `height`, with no margin. Used for icons beside text, at
  `Math.round(font.pixelSize * 0.875)`: a little taller than the letters.
  This is the sword beside the panel's title and the flag and globe on a
  row's second line.

## Alignment beside text

- An icon sits to the left of its text, with no separator characters between
  items. A row's second line is flag + realm, then globe + the world's
  computer, `Style.space(4)` between icon and text and `Style.space(10)`
  between items. The world's text is elided first.
- Center the icon vertically on the letters, not on the box. The title sword
  does this exactly, from `TextMetrics.tightBoundingRect`. The second line's
  icons center on the `Text` item instead, which lands on the middle of the
  capitals only because of the metrics of JetBrains Mono, Omarchy's
  `monospace` font. With another font, center them on the letters as the
  title does.
- An icon takes its text's color: `root.dim` on the second line,
  `root.foreground` beside the title, the accent on the tabs.

## Pitfall

A `Row` whose `visible` depends on its children's `visible` stays hidden for
good: a child's `visible` reads false while its parent is hidden. Test the
children's content, such as `text !== ""`, instead.
