import QtQuick
import QtQuick.Shapes
import "js/Icons.js" as Icons

Item {
    id: root

    property string name: "globe"
    property color color: Theme.foreground
    property real size: 16
    property real strokeWidth: 1.8

    width: size
    height: size

    readonly property real grid: 24.0
    readonly property real gridScale: root.size / root.grid

    Shape {
        width: root.grid
        height: root.grid
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            xScale: root.gridScale
            yScale: root.gridScale
        }

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin

            PathSvg {
                path: Icons.pathFor(root.name)
            }
        }
    }
}
