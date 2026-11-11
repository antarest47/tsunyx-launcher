import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker

// The only thing that ever lives in the panel: an icon button. Clicking it
// (or triggering the applet's configured keyboard shortcut, which fires
// Plasmoid.activated()) toggles the fullscreen TsunyxDashboard window,
// which is a completely separate top-level window, not a Plasma popup.
Item {
    id: root

    // Without explicit Layout size hints this Item has no implicit size,
    // which starves/squishes sibling applets in the panel's row layout.
    Layout.minimumWidth: -1
    Layout.minimumHeight: -1
    Layout.maximumWidth: Kirigami.Units.iconSizes.huge
    Layout.maximumHeight: Kirigami.Units.iconSizes.huge

    // Built lazily on first use, not eagerly at panel-load time: the
    // dashboard's whole app grid + harvesting machinery only needs to exist
    // once someone actually opens it, and merely adding this button to a
    // panel shouldn't pay that cost (or risk it misbehaving) up front.
    property QtObject dashboard: null

    function toggleDashboard() {
        if (!dashboard) {
            const component = Qt.createComponent(Qt.resolvedUrl("./TsunyxDashboard.qml"), root);
            if (component.status === Component.Error) {
                console.warn("Tsunyx: failed to load dashboard:", component.errorString());
                return;
            }
            dashboard = component.createObject(root, {
                visualParent: root,
                rootModel: rootModel,
                runnerModel: runnerModel,
                favoritesModel: rootModel.favoritesModel
            });
        }
        // Not dashboard.toggle(): that closes instantly with no exit
        // animation. requestToggle() plays the fade/slide-down first, then
        // actually hides once it's done.
        dashboard.requestToggle();
    }

    Kirigami.Icon {
        id: buttonIcon
        anchors.fill: parent
        source: Plasmoid.configuration.icon
        active: mouseArea.containsMouse
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.toggleDashboard()
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            root.toggleDashboard();
        }
    }
}
