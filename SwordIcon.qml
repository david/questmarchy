import QtQuick
import QtQuick.Shapes

// The Questmarchy sword, with path data from assets/sword.svg. The bar
// measures the path bounds and scales the shape to its icon size.
Shape {
  id: root

  property color color: "white"

  width: 24
  height: 24
  preferredRendererType: Shape.CurveRenderer

  // The blade.
  ShapePath {
    fillColor: root.color
    strokeColor: "transparent"
    strokeWidth: 0
    PathSvg {
      path: "M8.04 11.72 L13.98 5.78 Q15.96 3.80 20.06 3.94 Q20.20 8.04 18.22 10.02 L12.28 15.96 Z"
    }
  }

  // The crossguard, grip, and pommel.
  ShapePath {
    fillColor: root.color
    strokeColor: "transparent"
    strokeWidth: 0
    PathSvg {
      path: "M5.64 8.75 Q8.89 15.11 15.25 18.36 Q16.38 19.21 15.11 20.20 Q13.98 21.05 12.85 20.49 "
        + "Q6.77 17.23 3.51 11.15 Q2.95 10.02 3.80 8.89 Q4.79 7.62 5.64 8.75 Z "
        + "M7.33 15.25 L8.75 16.67 Q9.03 16.95 8.75 17.23 L7.05 18.93 Q6.77 19.21 6.48 18.93 "
        + "L5.07 17.52 Q4.79 17.23 5.07 16.95 L6.77 15.25 Q7.05 14.97 7.33 15.25 Z "
        + "M6.63 17.37 A2.1 2.1 0 1 1 3.66 20.34 A2.1 2.1 0 1 1 6.63 17.37 Z"
    }
  }
}
