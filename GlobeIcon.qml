import QtQuick
import QtQuick.Shapes

// The world globe, with path data from assets/globe.svg, drawn on the same
// 24-unit grid as the sword.
Shape {
  id: root

  property color color: "white"

  width: 24
  height: 24
  preferredRendererType: Shape.CurveRenderer

  // The rim.
  ShapePath {
    fillColor: root.color
    fillRule: ShapePath.OddEvenFill
    strokeColor: "transparent"
    strokeWidth: 0
    PathSvg {
      path: "M21 12 A9 9 0 1 1 3 12 A9 9 0 1 1 21 12 Z "
        + "M19 12 A7 7 0 1 1 5 12 A7 7 0 1 1 19 12 Z"
    }
  }

  // The meridian.
  ShapePath {
    fillColor: root.color
    fillRule: ShapePath.OddEvenFill
    strokeColor: "transparent"
    strokeWidth: 0
    PathSvg {
      path: "M16.6 12 A4.6 9 0 1 1 7.4 12 A4.6 9 0 1 1 16.6 12 Z "
        + "M14.6 12 A2.6 7 0 1 1 9.4 12 A2.6 7 0 1 1 14.6 12 Z"
    }
  }

  // The equator.
  ShapePath {
    fillColor: root.color
    strokeColor: "transparent"
    strokeWidth: 0
    PathSvg {
      path: "M4 11 L20 11 L20 13 L4 13 Z"
    }
  }
}
