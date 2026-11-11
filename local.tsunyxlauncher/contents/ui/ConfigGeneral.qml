import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.iconthemes as KIconThemes
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Kirigami.FormLayout {
    id: page

    property string cfg_icon: Plasmoid.configuration.icon
    property alias cfg_iconSize: iconSizeSlider.value
    property alias cfg_dimOpacity: dimOpacitySlider.value
    property alias cfg_showPageIndicator: showPageIndicatorCheck.checked
    property alias cfg_pagedMode: pagedModeCheck.checked
    property alias cfg_lampAnimation: lampRadio.checked

    QQC2.Button {
        id: iconButton
        Kirigami.FormData.label: i18n("Panel icon:")

        implicitWidth: Kirigami.Units.iconSizes.large + Kirigami.Units.largeSpacing * 2
        implicitHeight: implicitWidth

        // Just for visual feedback that the menu below is open; no
        // separate checkable state of its own is meaningful here.
        checkable: true
        checked: iconMenu.opened

        onPressed: iconMenu.opened ? iconMenu.close() : iconMenu.open()

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.large
            height: width
            source: page.cfg_icon
        }

        KIconThemes.IconDialog {
            id: iconDialog
            onAccepted: {
                if (iconDialog.iconName !== "") {
                    page.cfg_icon = iconDialog.iconName;
                }
            }
        }

        QQC2.Menu {
            id: iconMenu
            y: parent.height
            onClosed: iconButton.checked = false

            QQC2.MenuItem {
                text: i18nc("@item:inmenu Open icon chooser dialog", "Choose…")
                icon.name: "document-open-folder"
                onClicked: iconDialog.open()
            }
            QQC2.MenuItem {
                text: i18nc("@item:inmenu Reset icon to default", "Reset to default")
                icon.name: "edit-clear"
                onClicked: page.cfg_icon = "start-here-kde-symbolic"
            }
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Icon size:")

        QQC2.Slider {
            id: iconSizeSlider
            from: 48
            to: 160
            stepSize: 8
        }

        QQC2.Label {
            text: i18n("%1 px", Math.round(iconSizeSlider.value))
        }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Background dim:")

        QQC2.Slider {
            id: dimOpacitySlider
            from: 0.0
            to: 1.0
            stepSize: 0.05
        }

        QQC2.Label {
            text: Math.round(dimOpacitySlider.value * 100) + "%"
        }
    }

    QQC2.CheckBox {
        id: pagedModeCheck
        Kirigami.FormData.label: i18n("Layout:")
        text: i18n("Paginate the grid (uncheck for a scrolling list)")
    }

    QQC2.CheckBox {
        id: showPageIndicatorCheck
        Kirigami.FormData.label: i18n("Page dots:")
        text: i18n("Show page indicator")
        enabled: pagedModeCheck.checked
    }

    // Its own group: radio buttons with the same parent (this form) are
    // otherwise exclusive with the Uzunyx layout ones below.
    QQC2.ButtonGroup {
        id: animationGroup
    }

    QQC2.RadioButton {
        Kirigami.FormData.label: i18n("Open and close:")
        text: i18n("Icons fly out of the panel button")
        autoExclusive: false
        QQC2.ButtonGroup.group: animationGroup
        checked: !lampRadio.checked
    }

    QQC2.RadioButton {
        id: lampRadio
        text: i18n("Magic lamp (needs the Genie Anywhere desktop effect)")
        autoExclusive: false
        QQC2.ButtonGroup.group: animationGroup
    }
}
