import QtQuick

// A Canvas that draws at the real pixel size under the stage's scale, so
// it stays sharp: the inner Canvas is `pixelScale` times bigger and scaled
// back down. Paint in item coordinates: `ctx` comes pre-scaled. Override
// `draw(ctx)`; call `requestPaint()` to redraw.
Item {
  id: root

  property real pixelScale: 1
  function draw(ctx) {}
  function requestPaint() { cv.requestPaint() }

  onPixelScaleChanged: cv.requestPaint()
  onWidthChanged: cv.requestPaint()
  onHeightChanged: cv.requestPaint()

  Canvas {
    id: cv
    width: Math.max(1, Math.ceil(root.width * root.pixelScale))
    height: Math.max(1, Math.ceil(root.height * root.pixelScale))
    scale: 1 / root.pixelScale
    transformOrigin: Item.TopLeft
    renderStrategy: Canvas.Cooperative
    renderTarget: Canvas.FramebufferObject
    antialiasing: true
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.scale(root.pixelScale, root.pixelScale)
      root.draw(ctx)
    }
  }
}
