import QtQuick
import QtQuick.Shapes

// The realm flag, with path data from assets/flag.svg, drawn on the same
// 24-unit grid as the sword.
Shape {
  id: root

  property color color: "white"

  width: 24
  height: 24
  preferredRendererType: Shape.CurveRenderer

  // The pole and its round finial.
  ShapePath {
    fillColor: root.color
    strokeColor: "transparent"
    strokeWidth: 0
    PathSvg {
      path: "M5.1 4.5 L6.9 4.5 L6.9 20.1 Q6.9 21 6 21 Q5.1 21 5.1 20.1 Z"
    }
  }

  ShapePath {
    fillColor: root.color
    strokeColor: "transparent"
    strokeWidth: 0
    PathSvg {
      path: "M7.6 3.6 A1.6 1.6 0 1 1 4.4 3.6 A1.6 1.6 0 1 1 7.6 3.6 Z"
    }
  }

  // The waving cloth, with a swallowtail.
  ShapePath {
    fillColor: root.color
    strokeColor: "transparent"
    strokeWidth: 0
    PathSvg {
      path: "M6.5 6 Q10 4 13.5 6 Q16.5 7.7 20 6.2 Q20.6 6 20.3 6.6 L17.6 10 "
        + "L20.3 13.4 Q20.6 14 20 13.8 Q16.5 15.3 13.5 13.6 Q10 11.6 6.5 13.6 Z"
    }
  }
}
