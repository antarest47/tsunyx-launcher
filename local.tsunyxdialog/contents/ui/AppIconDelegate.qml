import QtQuick
import org.kde.kirigami as Kirigami

// A single GNOME-style app icon: big icon + label below, soft rounded
// highlight on hover/focus, no drop shadow, no background when idle.
Item {
    id: delegate

    property alias iconSource: appIcon.source
    property alias label: appLabel.text
    property int iconSize: 64

    signal activated()
    signal contextMenuRequested(real x, real y)
    signal mouseMoved()

    // "current" is driven externally by AppGridPage's keyboard-navigation
    // cursor, independent of the mouse — that's what makes arrow-key
    // navigation visible even when the pointer isn't over this icon.
    property alias hovered: mouseArea.containsMouse
    property bool current: false

    // containsMouse reads true immediately if this icon merely appears under
    // an already-stationary cursor (Qt synthesizes a hover recalculation
    // even with zero physical movement — onPositionChanged fires for that
    // too, so it can't be used to detect "real" movement either). Whether
    // hover should count at all is decided by the caller (ultimately by
    // comparing actual cursor coordinates against a baseline — see
    // TsunyxDashboard.qml's mouseNavActive) and passed in here.
    property bool mouseNavActive: true
    property bool highlighted: (hovered && mouseNavActive) || current

    Accessible.role: Accessible.Button
    Accessible.name: label

    Rectangle {
        id: highlight

        anchors.centerIn: appIcon
        width: appIcon.width + Kirigami.Units.largeSpacing * 2
        height: appIcon.width + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.cornerRadius * 3
        color: Kirigami.Theme.textColor
        opacity: delegate.highlighted ? 0.15 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    Kirigami.Icon {
        id: appIcon

        anchors.top: parent.top
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        width: delegate.iconSize
        height: width

        scale: mouseArea.pressed ? 0.92 : 1.0
        Behavior on scale {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
    }

    Text {
        id: appLabel

        anchors {
            top: appIcon.bottom
            topMargin: Kirigami.Units.smallSpacing
            left: parent.left
            right: parent.right
        }

        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.Wrap
        color: "white"
        font.pointSize: Kirigami.Theme.defaultFont.pointSize
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onPositionChanged: delegate.mouseMoved()

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                delegate.contextMenuRequested(mouse.x, mouse.y);
            } else {
                delegate.activated();
            }
        }
    }
}
