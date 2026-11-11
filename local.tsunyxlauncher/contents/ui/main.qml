import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: root

    // Always just a panel button; the real UI is the separate fullscreen
    // DashboardWindow created in CompactRepresentation.qml, not a Plasma
    // popup, so there's no "expanded" state to manage here.
    switchWidth: 0
    switchHeight: 0
    preferredRepresentation: fullRepresentation
    compactRepresentation: null
    fullRepresentation: compactRepresentationComponent

    Plasmoid.icon: Plasmoid.configuration.icon

    function action_menuedit() {
        processRunner.runMenuEditor();
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Edit Applications…")
            icon.name: "kmenuedit"
            visible: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            onTriggered: processRunner.runMenuEditor()
        }
    ]

    Component {
        id: compactRepresentationComponent
        CompactRepresentation {}
    }

    Kicker.RootModel {
        id: rootModel

        autoPopulate: false
        appNameFormat: 0
        flat: true
        sorted: true
        showSeparators: false
        appletInterface: root

        showAllApps: true
        showAllAppsCategorized: true
        showTopLevelItems: false
        showRecentApps: false
        showRecentDocs: false

        Component.onCompleted: {
            favoritesModel.initForClient("local.tsunyxlauncher.instance-" + Plasmoid.id);
            refresh();
        }
    }

    Kicker.RunnerModel {
        id: runnerModel

        favoritesModel: rootModel.favoritesModel
        appletInterface: root
        // Keep results split by runner category (Applications, Files, Web
        // Bookmarks...) instead of merged into one flat row, so the search
        // view can show them grouped like KRunner itself does.
        mergeResults: false
        // With mergeResults:false, an unset "runners" produced zero rows at
        // all (confirmed via debug logging) — unlike kicker's own dash mode,
        // which always sets this explicitly. Listing them out is what
        // actually turns categorized results on.
        // krunner_shell recognizes terminal commands; TsunyxDashboard.qml
        // puts that result first and runs it in a terminal that stays open.
        runners: ["krunner_services", "krunner_shell", "krunner_placesrunner", "krunner_bookmarksrunner",
            "krunner_recentdocuments", "baloosearch", "browsertabs", "browserhistory",
            "krunner_systemsettings", "krunner_sessions", "calculator", "unitconverter"]
    }

    Kicker.ProcessRunner {
        id: processRunner
    }
}
