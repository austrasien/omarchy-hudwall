import QtQuick
import qs.Commons

// All HUD text: plain text only (data comes from the daemon, the network,
// window titles), the shell's font, crisp under the stage's scale.
Text {
  textFormat: Text.PlainText
  font.family: Style.fontFamily
  font.pixelSize: 10
  renderType: Text.QtRendering
  elide: Text.ElideRight
}
