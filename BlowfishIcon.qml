import QtQuick
import QtQuick.Shapes
import qs.Commons

// Native, low-resolution blowfish mark. The broad silhouette and deliberately
// chunky features stay recognizable in an 11px bar slot without SVG filters.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property color cutoutColor: Color.background

  width: iconSize * 1.18
  height: iconSize
  implicitWidth: width
  implicitHeight: height

  readonly property real bodySize: height * 0.68
  readonly property real bodyX: width * 0.08
  readonly property real bodyY: (height - bodySize) / 2
  readonly property real spineWidth: Math.max(1, height * 0.075)
  readonly property real spineHeight: Math.max(2, height * 0.17)

  // Tail sits behind the body so its narrow root disappears into the fish.
  Shape {
    anchors.fill: parent
    antialiasing: true
    layer.enabled: true
    layer.samples: 4

    ShapePath {
      fillColor: root.color
      strokeWidth: 0
      startX: root.width * 0.67
      startY: root.height * 0.50
      PathLine { x: root.width * 0.98; y: root.height * 0.18 }
      PathLine { x: root.width * 0.90; y: root.height * 0.50 }
      PathLine { x: root.width * 0.98; y: root.height * 0.82 }
      PathLine { x: root.width * 0.67; y: root.height * 0.50 }
    }
  }

  Spine { x: root.width * 0.22; y: root.height * 0.03; rotation: -18 }
  Spine { x: root.width * 0.39; y: 0; rotation: 0 }
  Spine { x: root.width * 0.55; y: root.height * 0.04; rotation: 18 }
  Spine { x: root.width * 0.18; y: root.height * 0.80; rotation: 198 }
  Spine { x: root.width * 0.39; y: root.height * 0.83; rotation: 180 }
  Spine { x: root.width * 0.57; y: root.height * 0.78; rotation: 162 }

  Rectangle {
    x: root.bodyX
    y: root.bodyY
    width: root.bodySize
    height: root.bodySize
    radius: width / 2
    color: root.color
  }

  // One high-contrast eye reads better than internal detail at bar scale.
  Rectangle {
    x: root.bodyX + root.bodySize * 0.22
    y: root.bodyY + root.bodySize * 0.25
    width: Math.max(2, root.bodySize * 0.19)
    height: width
    radius: width / 2
    color: root.cutoutColor
  }

  // A tiny notch establishes the head direction without thinning the body.
  Rectangle {
    x: root.bodyX - 1
    y: root.bodyY + root.bodySize * 0.56
    width: Math.max(2, root.bodySize * 0.17)
    height: Math.max(1, root.bodySize * 0.08)
    color: root.cutoutColor
  }

  component Spine: Shape {
    id: spine
    width: Math.max(3, root.spineWidth * 2.4)
    height: root.spineHeight
    transformOrigin: Item.Bottom

    ShapePath {
      fillColor: root.color
      strokeWidth: 0
      startX: spine.width / 2
      startY: 0
      PathLine { x: spine.width; y: spine.height }
      PathLine { x: 0; y: spine.height }
      PathLine { x: spine.width / 2; y: 0 }
    }
  }
}
