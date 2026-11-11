/*
 * Tsunyx Search: a search box that lives in the panel itself.
 *
 * Typing searches apps, files, bookmarks... through KRunner, same as Tsunyx
 * Launcher, and shows the results in a popup above the box. If KRunner's
 * command line runner recognizes the text as a terminal command, running it
 * opens a terminal with the command, which stays open afterwards.
 *
 * The box keeps keyboard focus while typing: the applet reports
 * AcceptingInputStatus so the panel accepts keyboard input, and the results
 * popup never takes focus.
 *
 * Enter on a calculation adds the result to the box (see calculator.js), and
 * a duration offers to start a timer (see timer.js).
 *
 * When the panel reaches 90 % of the screen, the box becomes a button that
 * opens it in the applet's popup, and comes back once there's room for it.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker
import "calculator.js" as Calculator
import "timer.js" as TimerParser

PlasmoidItem {
    id: root

    // The text field lives inside the representation component, so it
    // reports its text and itself here.
    property string typed: ""
    property Item fieldItem: null
    // A calculation already answered in the box isn't searched for.
    property string shownAnswer: ""
    readonly property string query: typed === shownAnswer ? "" : typed.trim()
    readonly property bool searching: query !== ""
    // Flattened results in display order (see rebuildResults()).
    // Each: {section, isCommand, sourceModel, modelIndex, decoration, display},
    // and the timer's first, with {timer} instead of the model.
    property var results: []
    property int currentIndex: 0
    // Mouse highlighting only follows genuine pointer movement: content
    // appearing under a still pointer also fires hover events.
    property point lastPointer: Qt.point(-1, -1)

    onQueryChanged: rebuildResults()

    // The box in the panel or, for lack of room, a button.
    property bool collapsed: false
    readonly property int fieldWidth: Kirigami.Units.gridUnit * Plasmoid.configuration.fieldWidth
    readonly property int buttonWidth: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2

    // Decided on how wide the panel would be with the box, so the room the
    // button saves doesn't bring the box straight back; the margin keeps it
    // from flipping right at the limit.
    function updateCollapsed() {
        const panel = root.Window.window;
        if (!panel || Plasmoid.formFactor !== PlasmaCore.Types.Horizontal) {
            collapsed = false;
            return;
        }
        const withBox = panel.width + (collapsed ? fieldWidth - buttonWidth : 0);
        const limit = root.Screen.width * 0.9;
        collapsed = withBox >= (collapsed ? limit - Kirigami.Units.gridUnit * 2 : limit);
    }

    // After the panel settles: it resizes in steps.
    Timer {
        id: roomCheck
        interval: 500
        onTriggered: root.updateCollapsed()
    }
    Connections {
        target: root.Window.window
        function onWidthChanged() {
            roomCheck.restart();
        }
    }
    Component.onCompleted: roomCheck.restart()
    Screen.onWidthChanged: roomCheck.restart()

    onCollapsedChanged: {
        reset();
        expanded = false;
    }
    onExpandedChanged: isExpanded => {
        if (isExpanded && fieldItem) {
            startTyping();
        } else if (!isExpanded && collapsed && fieldItem) {
            fieldItem.text = "";
        }
    }

    preferredRepresentation: collapsed ? compactRepresentation : fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // KRunner's command line runner offers a "run in terminal" action on its
    // matches; its id and icon don't depend on the UI language, unlike the
    // runner's (translated) section name.
    function isCommandSection(section) {
        return section.entries.some(e => (e.actionList || []).some(a =>
            a.actionId === "runnerAction" && a.icon === "utilities-terminal"));
    }

    // Results keep KRunner's section order, except that a recognized command
    // goes first unless some result's name starts with what was typed: so
    // "fire" opens Firefox, while "ls" or "ls -la" run in a terminal instead
    // of a weak keyword match.
    function rebuildResults() {
        const sections = harvester.sections.map(s => Object.assign({ isCommand: isCommandSection(s) }, s));
        const typed = query.toLowerCase();
        const strongMatch = sections.some(s => !s.isCommand && s.entries.some(e =>
            String(e.display).toLowerCase().startsWith(typed)));
        const ordered = strongMatch ? sections
            : sections.filter(s => s.isCommand).concat(sections.filter(s => !s.isCommand));
        const flat = [];
        for (const section of ordered) {
            for (const entry of section.entries) {
                flat.push({
                    section: section.label,
                    isCommand: section.isCommand,
                    sourceModel: entry.sourceModel,
                    modelIndex: entry.modelIndex,
                    decoration: entry.decoration,
                    display: entry.display,
                });
            }
        }
        const timer = TimerParser.parse(query);
        if (timer && (timer.forced || !strongMatch)) {
            flat.unshift({
                section: i18nc("@title:group search results", "Timer"),
                isCommand: false,
                timer: timer,
                decoration: "chronometer",
                display: timer.label
                    ? i18nc("@action %1 a duration, %2 its name", "Start a %1 timer: %2", timer.text, timer.label)
                    : i18nc("@action %1 a duration", "Start a %1 timer", timer.text),
            });
        }
        results = flat;
        currentIndex = 0;
        lastPointer = Qt.point(-1, -1);
    }

    // Gives way to a result whose name starts with what was typed.
    function answerCalculation() {
        const lower = query.toLowerCase();
        const nameMatch = results.some(e => String(e.display).toLowerCase().startsWith(lower));
        const answer = Calculator.answer(typed, nameMatch);
        if (answer === null) {
            return false;
        }
        shownAnswer = answer;
        fieldItem.text = answer;
        return true;
    }

    function activate(index) {
        const entry = results[index];
        if (!entry) {
            return;
        }
        if (entry.timer) {
            executable.connectSource(TimerParser.command(entry.timer));
        } else if (entry.isCommand) {
            runInTerminal(query);
        } else {
            entry.sourceModel.trigger(entry.modelIndex, "", null);
        }
        reset();
    }

    // Runs the command through zsh (bash if missing) in a new terminal window, from the home
    // folder, keeping an interactive shell open after it ends so its output
    // stays visible.
    function runInTerminal(command) {
        const quote = text => "'" + text.replace(/'/g, "'\\''") + "'";
        // zsh, set up like Uzunyx's Konsole profile when the terminal doesn't do it.
        // With Uzunyx's zsh the command is typed in at its first prompt and run
        // there (UZUNYX_TERMINAL_RUN, uzunyx-terminal >= 0.7), so the prompt and
        // the command stay on screen; any other shell just runs it first.
        const script = 'cd "$HOME"; if command -v zsh >/dev/null; then '
            + '[ -n "$ZDOTDIR" ] || [ ! -d /usr/share/uzunyx-terminal/zsh ] || export ZDOTDIR=/usr/share/uzunyx-terminal/zsh; '
            + 'if grep -qs UZUNYX_TERMINAL_RUN "$ZDOTDIR/.zshrc"; then UZUNYX_TERMINAL_RUN="$1" exec zsh; fi; '
            + 'zsh -c "$1"; exec zsh; fi; bash -c "$1"; exec bash';
        const terminal = Plasmoid.configuration.terminalCommand || "konsole";
        executable.connectSource("setsid -f " + terminal + " -e sh -c " + quote(script) + " sh " + quote(command));
    }

    function reset() {
        if (fieldItem) {
            fieldItem.text = "";
            fieldItem.focus = false;
        }
        Plasmoid.status = PlasmaCore.Types.PassiveStatus;
        expanded = false;
    }

    function startTyping() {
        Plasmoid.status = PlasmaCore.Types.AcceptingInputStatus;
        if (fieldItem) {
            fieldItem.forceActiveFocus();
        }
    }

    Connections {
        target: Plasmoid
        // Global shortcut for the widget, if the user assigns one.
        function onActivated() {
            if (root.collapsed) {
                root.expanded = true;
            } else {
                root.startTyping();
            }
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: sourceName => disconnectSource(sourceName)
    }

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: root
        mergeResults: false
        runners: ["krunner_services", "krunner_shell", "krunner_placesrunner",
            "krunner_bookmarksrunner", "krunner_recentdocuments", "baloosearch",
            "browsertabs", "browserhistory", "krunner_systemsettings",
            "krunner_sessions", "calculator", "unitconverter"]
        query: root.query
    }

    CategorizedResultsHarvester {
        id: harvester
        sourceModel: runnerModel
        // Re-read each runner's rows on every keystroke (see the harvester).
        refreshKey: root.query
        onSectionsChanged: root.rebuildResults()
    }

    compactRepresentation: Item {
        Layout.minimumWidth: root.buttonWidth
        Layout.preferredWidth: root.buttonWidth
        Layout.maximumWidth: root.buttonWidth
        Layout.fillHeight: true

        PlasmaComponents3.ToolButton {
            property bool wasExpanded: false
            anchors.centerIn: parent
            icon.name: "search"
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
            // The popup closes when the press takes its focus away.
            onPressed: wasExpanded = root.expanded
            onClicked: root.expanded = !wasExpanded
        }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: root.collapsed ? Kirigami.Units.gridUnit * 26 : root.fieldWidth
        Layout.minimumWidth: root.collapsed ? Kirigami.Units.gridUnit * 26 : Kirigami.Units.gridUnit * 6
        Layout.minimumHeight: root.collapsed ? searchField.implicitHeight : -1
        Layout.preferredHeight: root.collapsed ? searchField.implicitHeight : -1
        Layout.fillHeight: !root.collapsed

        PlasmaComponents3.TextField {
            id: searchField
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            placeholderText: i18nc("@info:placeholder", "Search or run a command…")
            clearButtonShown: true
            // Room for the magnifier, same icon as Tsunyx Launcher's search pill.
            leftPadding: searchIcon.x + searchIcon.width + Kirigami.Units.smallSpacing

            Kirigami.Icon {
                id: searchIcon
                anchors.verticalCenter: parent.verticalCenter
                x: Kirigami.Units.smallSpacing * 2
                width: Kirigami.Units.iconSizes.small
                height: width
                source: "search"
                opacity: 0.7
            }

            onTextChanged: root.typed = text
            Component.onCompleted: root.fieldItem = searchField

            onPressed: root.startTyping()
            onActiveFocusChanged: {
                if (!activeFocus && !resultsPopup.visible && !root.collapsed) {
                    Plasmoid.status = PlasmaCore.Types.PassiveStatus;
                }
            }

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Down:
                    root.currentIndex = Math.min(root.currentIndex + 1, root.results.length - 1);
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                    root.currentIndex = Math.max(root.currentIndex - 1, 0);
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (!root.answerCalculation() && root.typed !== root.shownAnswer) {
                        root.activate(root.currentIndex);
                    }
                    event.accepted = true;
                    break;
                case Qt.Key_Escape:
                    root.reset();
                    event.accepted = true;
                    break;
                }
            }
        }

        // PlasmaCore.Dialog always centers itself on its visualParent. This
        // invisible item starts at the box's left edge and is as wide as the
        // popup, so "centered on it" means aligned with the box's left edge.
        Item {
            id: popupAnchor
            x: searchField.x
            y: searchField.y
            width: resultsList.width + resultsPopup.margins.left + resultsPopup.margins.right
            height: searchField.height
        }

        PlasmaCore.Dialog {
            id: resultsPopup
            visualParent: popupAnchor
            location: Plasmoid.location
            type: PlasmaCore.Dialog.PopupMenu
            flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
            hideOnWindowDeactivate: false
            visible: root.searching && root.results.length > 0

            mainItem: ListView {
                id: resultsList
                width: Math.max(searchField.width, Kirigami.Units.gridUnit * 26)
                height: Math.min(contentHeight, Kirigami.Units.gridUnit * 24)
                clip: true
                model: root.results
                currentIndex: root.currentIndex
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds

                section.property: "section"
                section.delegate: Kirigami.Heading {
                    required property string section
                    width: ListView.view.width
                    level: 5
                    opacity: 0.7
                    leftPadding: Kirigami.Units.smallSpacing
                    topPadding: Kirigami.Units.smallSpacing
                    text: section
                }

                highlight: Rectangle {
                    radius: Kirigami.Units.cornerRadius
                    color: Kirigami.Theme.highlightColor
                    opacity: 0.35
                }

                delegate: Item {
                    id: row
                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    height: Kirigami.Units.gridUnit * 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            source: row.modelData.isCommand ? "utilities-terminal" : row.modelData.decoration
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: row.modelData.isCommand
                                ? i18nc("@action run in a terminal", "Run in terminal: %1", root.query)
                                : row.modelData.display
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: mouse => {
                            const p = mapToGlobal(mouse.x, mouse.y);
                            if (root.lastPointer.x >= 0 && (p.x !== root.lastPointer.x || p.y !== root.lastPointer.y)) {
                                root.currentIndex = row.index;
                            }
                            root.lastPointer = p;
                        }
                        onClicked: root.activate(row.index)
                    }
                }
            }
        }
    }
}
