import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// Search box, the same as Tsunyx Search's in the panel: display-only (the real
// text input is the invisible TextInput used as the DashboardWindow
// keyEventProxy in TsunyxDashboard.qml, so "just start typing" works from
// anywhere in the grid). Clicking it focuses that hidden input for normal
// text editing (backspace, cursor movement, etc).
PlasmaComponents.TextField {
    id: field

    property bool active: false

    signal clicked()
    signal clearRequested()

    implicitWidth: Kirigami.Units.gridUnit * 22
    readOnly: true
    activeFocusOnPress: false
    activeFocusOnTab: false
    cursorVisible: active
    cursorPosition: text.length
    placeholderText: i18nc("@info:placeholder", "Search or run a command…")
    leftPadding: searchIcon.x + searchIcon.width + Kirigami.Units.smallSpacing
    rightPadding: clearIcon.width + Kirigami.Units.smallSpacing * 2

    Kirigami.Icon {
        id: searchIcon
        anchors.verticalCenter: parent.verticalCenter
        x: Kirigami.Units.smallSpacing * 2
        width: Kirigami.Units.iconSizes.small
        height: width
        source: "search"
        opacity: 0.7
    }

    MouseArea {
        anchors.fill: parent
        onClicked: field.clicked()
    }

    Kirigami.Icon {
        id: clearIcon
        anchors {
            right: parent.right
            rightMargin: Kirigami.Units.smallSpacing
            verticalCenter: parent.verticalCenter
        }
        width: Kirigami.Units.iconSizes.small
        height: width
        visible: field.text.length > 0
        source: "edit-clear-locationbar-rtl"

        MouseArea {
            anchors.fill: parent
            onClicked: field.clearRequested()
        }
    }
}
