import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// GNOME-style search pill: display-only (the real text input is the
// invisible TextInput used as the DashboardWindow keyEventProxy in
// TsunyxDashboard.qml, so "just start typing" works from anywhere in
// the grid). Clicking the pill focuses that hidden input for normal
// text editing (backspace, cursor movement, etc).
Rectangle {
    id: pill

    property alias text: label.text
    property bool active: false

    signal clicked()
    signal clearRequested()

    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: Kirigami.Units.gridUnit * 3
    radius: height / 2
    color: Qt.rgba(1, 1, 1, active ? 0.18 : 0.12)
    border.width: active ? 1 : 0
    border.color: Kirigami.Theme.highlightColor

    Kirigami.Icon {
        id: searchIcon
        anchors {
            left: parent.left
            leftMargin: Kirigami.Units.largeSpacing
            verticalCenter: parent.verticalCenter
        }
        width: Kirigami.Units.iconSizes.small
        height: width
        source: "search"
        color: "white"
        isMask: true
    }

    Text {
        id: label

        anchors {
            left: searchIcon.right
            leftMargin: Kirigami.Units.largeSpacing
            right: clearButton.visible ? clearButton.left : parent.right
            rightMargin: Kirigami.Units.largeSpacing
            verticalCenter: parent.verticalCenter
        }

        text: ""
        color: "white"
        opacity: text.length > 0 ? 1.0 : 0.6
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
        elide: Text.ElideRight

        // shown when there's no query yet
        Text {
            anchors.fill: parent
            visible: label.text.length === 0
            text: i18nc("@info:placeholder", "Type to search…")
            color: "white"
            opacity: 0.6
            font: label.font
        }
    }

    PlasmaComponents.ToolButton {
        id: clearButton
        anchors {
            right: parent.right
            rightMargin: Kirigami.Units.smallSpacing
            verticalCenter: parent.verticalCenter
        }
        visible: label.text.length > 0
        icon.name: "edit-clear"
        flat: true
        onClicked: pill.clearRequested()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: pill.clicked()
    }
}
