// windOS Zen — Calamares slideshow (static, on purpose)
// A single branded slide. No animation: the installer must stay
// responsive on a single-core Celeron.
// TEXT RULE: every string is light on the #090d16 base — #f8fafc headline,
// #cbd5e1 body (was #94a3b8, too dim at 11pt on the projector-throw path),
// #38bdf8 accent. Never a dark hex here.
import QtQuick 2.15

Rectangle {
    id: root
    width: 800
    height: 520
    // unified window base: same #090d16 as the backdrop rim, QSS chrome
    // and SidebarBackground — no black-on-deepblue seam around the slide.
    color: "#090d16"

    Column {
        anchors.centerIn: parent
        spacing: 18

        Image {
            source: "windos-banner.png"
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
            width: 460
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "windOS Zen 1.0 \"Breeze\" — Lighter Than Air"
            color: "#f8fafc"
            font.pointSize: 16
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Building lightweight systems isn't about what you add,\nit's about having the guts to remove everything that doesn't matter."
            horizontalAlignment: Text.AlignHCenter
            color: "#cbd5e1"
            font.pointSize: 11
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Pick your desktop on the previous page — the installer handles the rest."
            color: "#38bdf8"
            font.pointSize: 11
        }
    }
}
