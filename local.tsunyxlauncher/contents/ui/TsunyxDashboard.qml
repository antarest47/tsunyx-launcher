import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker
import "calculator.js" as Calculator
import "timer.js" as TimerParser

// GNOME-style app grid: paginated, dot indicator, search on top.
// Kicker.DashboardWindow gives us a real top-level window (dim background,
// Escape handling, keyboard proxy) for free; everything below mainItem is
// our own GNOME-flavored layout. Its true-fullscreen mode is immediately
// downgraded to Maximized below so it never covers the panel — see the
// comment on that in onVisibleChanged. The companion KWin script then
// stretches it over the whole screen, panel area included, with the panel
// drawn on top (GNOME dash style); panelInset keeps the content clear of it.
Kicker.DashboardWindow {
    id: root

    property QtObject rootModel
    property QtObject runnerModel
    property QtObject favoritesModel
    property QtObject allAppsModel: null

    readonly property int iconSize: Plasmoid.configuration.iconSize
    readonly property int cellSize: iconSize + Kirigami.Units.gridUnit * 3
    readonly property bool searching: hiddenSearchInput.text !== ""
    // A calculation already answered in the box isn't searched for.
    property string shownAnswer: ""
    readonly property string query: hiddenSearchInput.text === shownAnswer ? "" : hiddenSearchInput.text.trim()
    // Search sections in display order, see orderSearchSections().
    readonly property var searchSections: orderSearchSections(searchHarvester.sections)

    // KRunner's command line runner offers a "run in terminal" action on its
    // matches; its id and icon don't depend on the UI language, unlike the
    // runner's (translated) section name. Same check as Tsunyx Search.
    function isCommandSection(section) {
        return section.entries.some(e => (e.actionList || []).some(a =>
            a.actionId === "runnerAction" && a.icon === "utilities-terminal"));
    }

    // KRunner's section order, except that a recognized terminal command
    // goes first unless some result's name starts with what was typed: so
    // "fire" opens Firefox, while "ls" or "ls -la" run in a terminal instead
    // of a weak keyword match. Command entries are marked with isCommand and
    // show the whole typed command under a terminal icon.
    function orderSearchSections(sections) {
        const typed = query.toLowerCase();
        const marked = sections.map(s => {
            if (!isCommandSection(s)) {
                return s;
            }
            return {
                label: i18nc("@title:group search results", "Run in terminal"),
                isCommand: true,
                entries: s.entries.map(e => Object.assign({}, e, {
                    isCommand: true,
                    decoration: "utilities-terminal",
                    display: root.query,
                })),
            };
        });
        const strongMatch = marked.some(s => !s.isCommand && s.entries.some(e =>
            String(e.display).toLowerCase().startsWith(typed)));
        const ordered = strongMatch ? marked
            : marked.filter(s => s.isCommand).concat(marked.filter(s => !s.isCommand));
        // A duration offers to start a timer, first (see timer.js).
        const timer = TimerParser.parse(query);
        if (!timer || !(timer.forced || !strongMatch)) {
            return ordered;
        }
        return [{
            label: i18nc("@title:group search results", "Timer"),
            entries: [{
                timer: timer,
                decoration: "chronometer",
                display: timer.label
                    ? i18nc("@action %1 a duration, %2 its name", "Start a %1 timer: %2", timer.text, timer.label)
                    : i18nc("@action %1 a duration", "Start a %1 timer", timer.text),
                actionList: [],
            }],
        }].concat(ordered);
    }

    // Enter on a calculation: the box keeps it and adds the result. Gives way
    // to a result whose name starts with what was typed (see calculator.js).
    function answerCalculation() {
        const typed = query.toLowerCase();
        const nameMatch = searchHarvester.sections.some(s => s.entries.some(e =>
            String(e.display).toLowerCase().startsWith(typed)));
        const answer = Calculator.answer(hiddenSearchInput.text, nameMatch);
        if (answer === null) {
            return false;
        }
        shownAnswer = answer;
        hiddenSearchInput.text = answer;
        return true;
    }

    // Runs the command through zsh (bash if missing) in a new terminal window, from the home
    // folder, keeping an interactive shell open after it ends so its output
    // stays visible. KRunner's own "run in terminal" closes the window when
    // the command ends.
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

    // A property, not a child: DashboardWindow only takes Items as children.
    readonly property QtObject executable: P5Support.DataSource {
        engine: "executable"
        onNewData: sourceName => disconnectSource(sourceName)
    }

    // How far the panel holding this launcher reaches into the screen from
    // its edge: its window's thickness, floating margins included. The
    // window spans the whole screen with the panel on top (see the KWin
    // script), so the content keeps this much clear on the panel's edge.
    readonly property QtObject panelWindow: visualParent ? visualParent.Window.window : null
    readonly property bool panelVertical: Plasmoid.location === PlasmaCore.Types.LeftEdge
        || Plasmoid.location === PlasmaCore.Types.RightEdge
    readonly property int panelInset: panelWindow
        ? (panelVertical ? panelWindow.width : panelWindow.height) : 0

    // 0 = fully hidden, 1 = fully revealed. Driven to 1 right after opening
    // and back to 0 on close — see requestClose()/requestToggle(). It's a
    // linear clock: every app icon flies out of the panel button and back
    // on its own share of it, eased and staggered by distance
    // (AppIconDelegate.qml), so a wave leaves the button. The background
    // dim has its own progress and duration.
    property real revealProgress: 0
    readonly property int revealDuration: 500
    property real backgroundRevealProgress: 0
    readonly property int backgroundRevealDuration: 600
    readonly property int closeBackgroundDuration: 500
    property bool closing: false

    // Magic lamp mode: the Genie Anywhere KWin effect animates the whole
    // window opening out of the cursor (the panel button) and closing back
    // into it, so the launcher shows and hides at once, without its own
    // icon flight, dim fade or opacity fade (the KWin script leaves the
    // window opaque). The effect and the script recognize this mode by the
    // window title (windowTitle).
    readonly property bool lampMode: Plasmoid.configuration.lampAnimation
    // In lamp mode the title also carries the panel button's centre in this
    // window's coordinates ("Tsunyx Launcher (lamp) 652,1172"): KWin can't
    // see inside the panel, so that's how the effect knows where the lamp
    // is, also when the launcher is opened with the Meta key.
    readonly property string windowTitle: lampMode
        ? "Tsunyx Launcher (lamp) " + Math.round(flyOrigin.x) + "," + Math.round(flyOrigin.y)
        : "Tsunyx Launcher"

    Behavior on revealProgress {
        enabled: !root.lampMode
        NumberAnimation { duration: root.revealDuration; easing.type: Easing.Linear }
    }
    Behavior on backgroundRevealProgress {
        enabled: !root.lampMode
        // On close the dim lasts as long as the icons' flight back, so it
        // doesn't clear out before they reach the button.
        NumberAnimation {
            duration: root.closing ? root.closeBackgroundDuration : root.backgroundRevealDuration
            easing.type: Easing.OutCubic
        }
    }

    backgroundColor: Qt.rgba(0, 0, 0, Plasmoid.configuration.dimOpacity * backgroundRevealProgress)

    // Where the icons fly from: the panel button's centre in this window's
    // coordinates, taken on every open (the panel may have moved). The app
    // icons read these through their window (AppIconDelegate.qml);
    // flyGeneration tells them to measure their offsets again.
    property point flyOrigin: Qt.point(0, 0)
    property real flyMaxDistance: 1
    property int flyGeneration: 0
    function updateFlyOrigin() {
        if (!visualParent) {
            return;
        }
        const button = visualParent.mapToGlobal(visualParent.width / 2, visualParent.height / 2);
        const viewGlobal = view.mapToGlobal(0, 0);
        const viewScene = view.mapToItem(null, 0, 0);
        flyOrigin = Qt.point(button.x - viewGlobal.x + viewScene.x, button.y - viewGlobal.y + viewScene.y);
        // The screen, not the view: the view isn't laid out yet on the first open.
        flyMaxDistance = Math.hypot(Screen.width, Screen.height);
        flyGeneration++;
    }
    keyEventProxy: hiddenSearchInput

    // Kicker.DashboardWindow's own toggle()/hide() close instantly, with no
    // chance to play an exit animation first. These wrap them: play the
    // fade/slide out, THEN actually hide. Every internal close (Escape,
    // background click, launching an app, a favorite-menu action that
    // requests closing) goes through requestClose(), and
    // CompactRepresentation.qml calls requestToggle() instead of toggle()
    // for the same reason.
    function requestToggle() {
        if (root.visible) {
            requestClose();
        } else {
            root.toggle();
        }
    }

    function requestClose() {
        if (closing) {
            return;
        }
        if (lampMode) {
            // Hide right away, content untouched: the lamp effect shows the
            // window's last frame going back into the button.
            root.hide();
            return;
        }
        closing = true;
        revealProgress = 0;
        backgroundRevealProgress = 0;
        // Tells the companion KWin script the close animation started, so it
        // fades the window's opacity (and with it KWin's blur behind it,
        // which this window can't fade by itself) in step with the content
        // sliding out. onVisibleChanged sets the plain title back on open,
        // which the script takes as the cue to fade in.
        if (view.Window.window) {
            view.Window.window.title = "Tsunyx Launcher (closing)";
        }
        closeTimer.restart();
    }

    // Another window taking the focus (one that opened on its own, a click in
    // the panel, Alt+Tab) closes the launcher, as it would close a menu: before,
    // it stayed open underneath. Its own context menu takes the focus too, so it
    // waits a moment and lets that one be.
    // Properties, not children: DashboardWindow only takes Items as children.
    readonly property QtObject focusWatcher: Connections {
        target: view.Window.window
        function onActiveChanged() {
            if (view.Window.window && !view.Window.window.active && root.visible && !root.closing) {
                root.focusLostTimer.restart();
            }
        }
    }
    readonly property QtObject focusLostTimer: Timer {
        interval: 300
        onTriggered: {
            const window = view.Window.window;
            if (window && !window.active && root.visible && !root.closing && !contextMenu.shown) {
                root.requestClose();
            }
        }
    }

    function findAllAppsModel() {
        if (!rootModel) {
            return;
        }
        for (let i = 0; i < rootModel.count; i++) {
            const m = rootModel.modelForRow(i);
            if (m && m.description === "KICKER_ALL_MODEL") {
                allAppsModel = m;
                return;
            }
        }
    }

    function reset() {
        hiddenSearchInput.text = "";
        findAllAppsModel();
        pageSwipe.setCurrentIndex(0);
        // The dashboard window is only hidden/shown between opens, never
        // recreated, so each AppGridPage's currentIndex would otherwise
        // stay wherever it was left at last close. Land back on the first
        // item of the first page every time instead.
        for (let i = 0; i < pageSwipe.count; i++) {
            const p = pageSwipe.itemAt(i);
            if (p) {
                p.currentIndex = p.entries.length > 0 ? 0 : -1;
            }
        }
        // Same idea for the vertical-scroll mode's single list, plus
        // scrolling it back to the top.
        verticalGridPage.currentIndex = verticalGridPage.entries.length > 0 ? 0 : -1;
        verticalGridArea.contentY = 0;
        searchArea.contentY = 0;
        view.resetMouseNav();
    }

    onVisibleChanged: {
        if (visible) {
            updateFlyOrigin();
            reset();
            view.forceActiveFocus();
            // Both are already 0 at this point (closeTimer only flips the
            // window invisible after they've finished animating back down),
            // so this triggers the entrance: dim fade in, icons fly out.
            revealProgress = 1;
            backgroundRevealProgress = 1;

            // Gives this window a stable, unique title so the companion
            // KWin script (kwin-script-skip-taskbar/, needed for the
            // keepPanelVisible case below) can find it — it otherwise runs
            // inside plasmashell's own process, sharing that resourceClass
            // with every other Plasma popup, so title is the only reliable
            // match. Same generic-Window-attached-property route as the
            // visibility override below, for the same reason.
            if (view.Window.window) {
                view.Window.window.title = root.windowTitle;
            }

            // Kicker.DashboardWindow shows itself via
            // QWindow::showFullScreen(), which KWin elevates above the
            // panel's dock layer (that's how a fullscreen window is
            // normally allowed to cover a taskbar). "visibility" itself
            // isn't reachable straight off "root" — it's gated by this
            // module's own QML revision (0.1) even though the underlying
            // object is a real QQuickWindow — but reaching the same window
            // through the generic Window attached property on a plain Item
            // resolves against QtQuick.Window's revision instead, sidestepping
            // that check. Downgrading to Maximized keeps the window
            // borderless and screen-sized but in the normal window layer, so
            // a panel with "Always Visible" stays on top instead of being
            // covered, and its reserved strut keeps Maximized from
            // extending under it. Always on now (not configurable) — the
            // launcher covering the panel turned out to be the wrong
            // default entirely, not something worth keeping as an option.
            if (view.Window.window) {
                view.Window.window.visibility = Window.Maximized;
            }
        }
    }

    // The window keeps its title between opens and the lamp effect checks it
    // as soon as the window appears, so switch it as soon as the mode changes.
    onWindowTitleChanged: {
        if (view.Window.window) {
            view.Window.window.title = windowTitle;
        }
    }

    onKeyEscapePressed: {
        if (searching) {
            hiddenSearchInput.text = "";
        } else {
            root.requestClose();
        }
    }

    Component.onCompleted: findAllAppsModel()

    mainItem: Item {
        id: view
        anchors {
            fill: parent
            topMargin: Plasmoid.location === PlasmaCore.Types.TopEdge ? root.panelInset : 0
            bottomMargin: Plasmoid.location === PlasmaCore.Types.BottomEdge ? root.panelInset : 0
            leftMargin: Plasmoid.location === PlasmaCore.Types.LeftEdge ? root.panelInset : 0
            rightMargin: Plasmoid.location === PlasmaCore.Types.RightEdge ? root.panelInset : 0
        }
        focus: true

        // computed grid geometry
        readonly property int topArea: Kirigami.Units.gridUnit * 8
        readonly property int bottomArea: Kirigami.Units.gridUnit * 4
        readonly property int columns: Math.max(1, Math.floor(width / root.cellSize))
        readonly property int rows: Math.max(1, Math.floor((height - topArea - bottomArea) / root.cellSize))
        readonly property int perPage: columns * rows
        readonly property int gridWidth: columns * root.cellSize
        readonly property int gridHeight: rows * root.cellSize

        // Whether hover is allowed to steal the keyboard-navigation cursor
        // right now. Comparing actual cursor coordinates against a baseline
        // (recorded the moment the dashboard opens) is the only reliable way
        // to tell "the mouse genuinely moved" apart from "content just
        // appeared under an already-stationary cursor" — Qt fires the same
        // hover/positionChanged signals for both, so watching for an event
        // doesn't work, only comparing the actual numbers does.
        property real _mouseBaselineX: -1
        property real _mouseBaselineY: -1
        property bool mouseNavActive: false

        function resetMouseNav() {
            mouseNavActive = false;
            _mouseBaselineX = -1;
            _mouseBaselineY = -1;
        }

        // Kicker.DashboardWindow only accepts Item children directly (a
        // Timer placed at the top level, outside mainItem, failed the
        // whole component with "Cannot assign object of type Timer to
        // property of type QQuickItem*" — silently breaking dashboard
        // creation and making the launcher not open at all). Belongs here
        // instead, since "view" is a plain Item.
        Timer {
            id: closeTimer
            // Both exit animations now run at revealDuration while closing
            // (see the backgroundRevealProgress Behavior above), so this
            // only needs to wait that long, not the longer open-only
            // backgroundRevealDuration.
            interval: root.revealDuration + 20
            onTriggered: {
                root.closing = false;
                root.hide();
            }
        }

        HoverHandler {
            id: globalMouseTracker
            onPointChanged: {
                if (view._mouseBaselineX < 0) {
                    view._mouseBaselineX = point.position.x;
                    view._mouseBaselineY = point.position.y;
                    return;
                }
                if (!view.mouseNavActive) {
                    const dx = point.position.x - view._mouseBaselineX;
                    const dy = point.position.y - view._mouseBaselineY;
                    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                        view.mouseNavActive = true;
                    }
                }
            }
        }

        // Centralized keyboard navigation: whichever AppGridPage is showing
        // (the current grid-mode page, or the search results page) gets its
        // currentIndex cursor moved. Kept here rather than on the individual
        // pages/SwipeView so there's a single owner of actual QML focus.
        function movePageCursor(page, delta, allowPageWrap) {
            if (!page || page.entries.length === 0) {
                return;
            }
            const cols = Math.max(1, page.columns);
            if (page.currentIndex < 0) {
                page.currentIndex = 0;
                return;
            }
            if (allowPageWrap && (delta === 1 || delta === -1)) {
                const col = page.currentIndex % cols;
                if (delta === 1 && col === cols - 1 && pageSwipe.currentIndex < pageSwipe.count - 1) {
                    pageSwipe.incrementCurrentIndex();
                    const nextPage = pageSwipe.currentItem();
                    if (nextPage) {
                        nextPage.currentIndex = 0;
                    }
                    return;
                }
                if (delta === -1 && col === 0 && pageSwipe.currentIndex > 0) {
                    pageSwipe.decrementCurrentIndex();
                    const prevPage = pageSwipe.currentItem();
                    if (prevPage) {
                        prevPage.currentIndex = prevPage.entries.length - 1;
                    }
                    return;
                }
            }
            const next = page.currentIndex + delta;
            if (next >= 0 && next < page.entries.length) {
                page.currentIndex = next;
            }
        }

        // PageUp/PageDown in vertical-scroll mode: no pages to jump
        // between, so scroll verticalGridArea (a plain Flickable) by one
        // screenful instead. Programmatic contentY assignment isn't
        // auto-clamped the way interactive dragging is, so this clamps by
        // hand.
        function scrollVerticalPage(direction) {
            const flick = verticalGridArea;
            const maxY = Math.max(0, flick.contentHeight - flick.height);
            flick.contentY = Math.max(0, Math.min(maxY, flick.contentY + direction * flick.height));
        }

        // Moving the keyboard cursor with movePageCursor() only changes
        // verticalGridPage.currentIndex — it doesn't know anything about
        // scrolling, so without this the highlighted icon could move
        // arbitrarily far below/above the visible viewport with nothing
        // appearing to happen.
        function ensureVerticalCurrentVisible() {
            const flick = verticalGridArea;
            if (verticalGridPage.currentIndex < 0) {
                return;
            }
            const cols = Math.max(1, verticalGridPage.columns);
            const row = Math.floor(verticalGridPage.currentIndex / cols);
            const itemTop = row * root.cellSize;
            const itemBottom = itemTop + root.cellSize;
            if (itemTop < flick.contentY) {
                flick.contentY = itemTop;
            } else if (itemBottom > flick.contentY + flick.height) {
                flick.contentY = itemBottom - flick.height;
            }
        }

        // Same idea as ensureVerticalCurrentVisible() above, but for the
        // search-results Flickable: without it, arrowing past the bottom of
        // the visible viewport moved searchResultsView's selection cursor
        // fine, but nothing scrolled searchArea to follow it, so the
        // highlighted icon could end up entirely off-screen.
        function ensureSearchCurrentVisible() {
            const bounds = searchResultsView.currentItemBounds();
            if (!bounds) {
                return;
            }
            const flick = searchArea;
            if (bounds.top < flick.contentY) {
                flick.contentY = bounds.top;
            } else if (bounds.bottom > flick.contentY + flick.height) {
                flick.contentY = bounds.bottom - flick.height;
            }
        }

        Keys.onPressed: event => {
            if (root.searching) {
                switch (event.key) {
                case Qt.Key_Right:
                    searchResultsView.moveHorizontal(1);
                    event.accepted = true;
                    break;
                case Qt.Key_Left:
                    searchResultsView.moveHorizontal(-1);
                    event.accepted = true;
                    break;
                case Qt.Key_Down:
                    searchResultsView.moveVertical(1);
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                    searchResultsView.moveVertical(-1);
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (!root.answerCalculation() && hiddenSearchInput.text !== root.shownAnswer) {
                        searchResultsView.activateCurrent();
                    }
                    event.accepted = true;
                    break;
                }
                if (event.accepted) {
                    ensureSearchCurrentVisible();
                }
                return;
            }

            const paged = Plasmoid.configuration.pagedMode;
            const page = paged ? pageSwipe.currentItem() : verticalGridPage;
            switch (event.key) {
            case Qt.Key_Right:
                // allowPageWrap only makes sense in paged mode — in the
                // vertical list there's no page to jump into, just clamp.
                movePageCursor(page, 1, paged);
                event.accepted = true;
                break;
            case Qt.Key_Left:
                movePageCursor(page, -1, paged);
                event.accepted = true;
                break;
            case Qt.Key_Down:
                movePageCursor(page, Math.max(1, view.columns), false);
                event.accepted = true;
                break;
            case Qt.Key_Up:
                movePageCursor(page, -Math.max(1, view.columns), false);
                event.accepted = true;
                break;
            case Qt.Key_PageDown:
                if (paged) {
                    pageSwipe.incrementCurrentIndex();
                } else {
                    scrollVerticalPage(1);
                }
                event.accepted = true;
                break;
            case Qt.Key_PageUp:
                if (paged) {
                    pageSwipe.decrementCurrentIndex();
                } else {
                    scrollVerticalPage(-1);
                }
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (page) {
                    page.activateCurrent();
                }
                event.accepted = true;
                break;
            }

            if (!paged) {
                switch (event.key) {
                case Qt.Key_Right:
                case Qt.Key_Left:
                case Qt.Key_Down:
                case Qt.Key_Up:
                    ensureVerticalCurrentVisible();
                    break;
                }
            }
        }

        MouseArea {
            // The whole window, not just "view": also the strips beside a
            // panel that doesn't span its edge (view is inset by panelInset).
            anchors {
                fill: parent
                topMargin: -view.anchors.topMargin
                bottomMargin: -view.anchors.bottomMargin
                leftMargin: -view.anchors.leftMargin
                rightMargin: -view.anchors.rightMargin
            }
            z: -1
            onClicked: if (!root.searching) root.requestClose();
        }

        // Real text input: kept invisible and used as the DashboardWindow
        // keyEventProxy, so typing anywhere in the grid starts a search
        // without having to click into a field first (matches GNOME).
        TextInput {
            id: hiddenSearchInput
            width: 0
            height: 0
            visible: false
            persistentSelection: true

            onTextChanged: {
                if (root.runnerModel) {
                    root.runnerModel.query = root.query;
                }
            }
        }

        // Everything the user actually looks at (search pill, grid, page
        // dots, search results) lives in here instead of directly in
        // "view", so it can be slid up/down as one block on open/close
        // without disturbing the full-size background click-catcher, hidden
        // search input, or the mouse-position baseline tracker above, none
        // of which should move.
        Item {
            id: contentSlide
            x: 0
            width: view.width
            height: view.height
            // Kept still: the app icons fly out of the panel button on
            // their own (AppIconDelegate.qml).
            y: 0

        SearchField {
            id: searchPill

            anchors {
                top: parent.top
                topMargin: Kirigami.Units.gridUnit * 3
                horizontalCenter: parent.horizontalCenter
            }

            text: hiddenSearchInput.text
            active: hiddenSearchInput.activeFocus

            onClicked: hiddenSearchInput.forceActiveFocus()
            onClearRequested: hiddenSearchInput.text = ""
        }

        GroupedAppsHarvester {
            id: appsHarvester
            groupsModel: root.allAppsModel
        }

        CategorizedResultsHarvester {
            id: searchHarvester
            sourceModel: (root.query !== "" && root.runnerModel) ? root.runnerModel : null
            // Forces modelForRow() to be re-fetched on every keystroke, not
            // just once when search mode is first entered.
            refreshKey: hiddenSearchInput.text
        }

        // --- Grid mode: fixed pages, GNOME-style ---
        Item {
            id: gridArea
            visible: !root.searching && Plasmoid.configuration.pagedMode
            anchors {
                top: parent.top
                topMargin: view.topArea
                horizontalCenter: parent.horizontalCenter
            }
            width: view.gridWidth
            height: view.gridHeight

            // A plain Flickable instead of QQC2.SwipeView: debug logging
            // (temporarily added, since removed) proved the two-finger
            // touchpad swipe on this machine generates ZERO wheel events —
            // it's handled entirely as native Flickable drag, which
            // SwipeView's internal ListView commits to the next page only
            // past ~50% of the page width dragged. That threshold isn't
            // exposed as a tunable property, so this reimplements paging
            // directly to get a much lower, fully-controlled snapThreshold.
            // Keeps the same external API (currentIndex/count/currentItem/
            // itemAt/increment/decrementCurrentIndex/setCurrentIndex) so
            // nothing else in this file needed to change.
            Flickable {
                id: pageSwipe
                anchors.fill: parent
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: Math.max(width, pageRepeater.count * width)
                contentHeight: height

                property int currentIndex: 0
                readonly property int count: pageRepeater.count
                readonly property real snapThreshold: 0.15

                function itemAt(i) {
                    return pageRepeater.itemAt(i);
                }
                // A function, not a cached "readonly property Item" binding:
                // a property binding here only re-evaluates when
                // currentIndex changes, which in normal single-page use
                // never happens — if it first evaluated before pageRepeater
                // had populated (entirely possible, since the app list
                // harvests asynchronously), it would cache a stale null
                // forever and every keyboard press would silently no-op.
                // Confirmed exactly this: search-mode navigation (which
                // calls a function fresh every time, see
                // SearchResultsView.currentPage()) kept working while
                // grid-mode navigation using this stopped dead.
                function currentItem() {
                    return pageRepeater.itemAt(currentIndex);
                }
                function setCurrentIndex(i) {
                    currentIndex = Math.max(0, Math.min(count - 1, i));
                }
                function incrementCurrentIndex() {
                    setCurrentIndex(currentIndex + 1);
                }
                function decrementCurrentIndex() {
                    setCurrentIndex(currentIndex - 1);
                }

                onCurrentIndexChanged: {
                    if (!dragging && !flicking) {
                        contentX = currentIndex * width;
                    }
                }

                onMovementEnded: {
                    const frac = (contentX - currentIndex * width) / width;
                    if (frac > snapThreshold && currentIndex < count - 1) {
                        currentIndex += 1;
                    } else if (frac < -snapThreshold && currentIndex > 0) {
                        currentIndex -= 1;
                    }
                    contentX = currentIndex * width;
                }

                Behavior on contentX {
                    enabled: !pageSwipe.dragging && !pageSwipe.flicking
                    NumberAnimation {
                        id: contentXAnim
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutCubic
                    }
                }

                Repeater {
                    id: pageRepeater
                    model: {
                        const list = appsHarvester.entries;
                        const per = Math.max(1, view.perPage);
                        const pages = [];
                        for (let i = 0; i < list.length; i += per) {
                            pages.push(list.slice(i, i + per));
                        }
                        return pages.length > 0 ? pages : [[]];
                    }

                    delegate: AppGridPage {
                        id: gridPageDelegate
                        required property var modelData
                        required property int index
                        x: index * pageSwipe.width
                        width: pageSwipe.width
                        height: pageSwipe.height
                        entries: modelData
                        columns: view.columns
                        cellSize: root.cellSize
                        iconSize: root.iconSize
                        mouseNavActive: view.mouseNavActive

                        // A full page is a few dozen Kirigami.Icon + Text +
                        // MouseArea items; without this, panning between
                        // pages has to re-composite every single one of them
                        // each frame, which is what was showing up as low
                        // FPS regardless of what drives the pan (the
                        // Flickable rewrite changed the animation curve, not
                        // this cost, which is why it made no difference).
                        // Caching each page as one texture while it's moving
                        // turns that into a single cheap translated blit.
                        // pageSwipe.moving only covers interactive drag/flick
                        // — the keyboard/dot-driven path is a plain Behavior
                        // animation with no "moving" state at all, so it was
                        // never actually layered before despite being tested
                        // and reported janky too.
                        layer.enabled: pageSwipe.moving || contentXAnim.running
                        layer.smooth: true

                        onActivated: entry => {
                            entry.sourceModel.trigger(entry.modelIndex, "", null);
                            root.requestClose();
                        }
                        onContextMenuRequested: (entry, x, y) => {
                            contextMenu.sourceModel = entry.sourceModel;
                            contextMenu.actionList = entry.actionList;
                            contextMenu.favoriteId = entry.favoriteId;
                            contextMenu.pendingIndex = entry.modelIndex;
                            contextMenu.visualParent = gridPageDelegate;
                            contextMenu.open(x, y);
                        }
                    }
                }

            }

            // Kicker.DashboardWindow swallows wheel events before Qt Quick's
            // normal scene-graph delivery ever reaches child items — a plain
            // WheelHandler never fired here no matter where it was placed
            // (sibling of pageSwipe, child of pageSwipe, even one covering
            // the entire window), confirmed live with debug logging at each
            // level in turn. Kicker's own reference ItemMultiGridView.qml
            // hits the same wall and works around it with exactly this: an
            // overlay that captures the event directly (by being the
            // topmost item, anchors.fill + z above) instead of relying on
            // normal delivery ever reaching it.
            //
            // Its "destination" property (meant for forwarding onto a
            // ScrollView's internal wheel area) didn't produce any usable
            // result here — a plain Flickable apparently isn't a valid
            // target for whatever relay protocol that expects. Listening to
            // wheelMoved directly instead (no qmltypes exist for this
            // private type to document it — confirmed its actual shape
            // live via debug logging): it fires with a single {x, y}
            // point, and the two axes carry genuinely different semantics
            // depending on the input device. Touchpad two-finger swipe
            // reports on x: an *accumulated* position that grows the
            // longer/faster the gesture continues and resets to (0, 0)
            // once it ends, y staying 0 throughout. A real mouse wheel
            // reports on y instead, as a fixed ±120 per notch, x staying 0
            // — and critically, it never sends a (0, 0) "gesture ended"
            // event at all, so resetting "triggered" can't rely on that
            // for this input type. Negative (x or y) matches a downward
            // scroll (same sign convention already figured out for
            // angleDelta.y) -> next page/right; positive -> previous
            // page/left.
            Kicker.WheelInterceptor {
                anchors.fill: pageSwipe
                z: 1

                readonly property real threshold: 100
                // Only one page-change per gesture/notch: the touchpad's
                // accumulated x keeps climbing well past the threshold for
                // as long as the gesture continues, and a fast wheel spin
                // can report several notches within a few milliseconds of
                // each other — without this, either would fire repeatedly
                // instead of once.
                property bool triggered: false

                Timer {
                    id: cooldown
                    // Touchpad gestures still reset immediately via (0, 0)
                    // below; this is what actually resets "triggered" for
                    // the mouse-wheel case, which never sends that.
                    interval: 150
                    onTriggered: parent.triggered = false
                }

                onWheelMoved: point => {
                    if (point.x === 0 && point.y === 0) {
                        triggered = false;
                        return;
                    }
                    cooldown.restart();
                    if (triggered) {
                        return;
                    }
                    const value = point.x !== 0 ? point.x : point.y;
                    if (value < -threshold) {
                        pageSwipe.incrementCurrentIndex();
                        triggered = true;
                    } else if (value > threshold) {
                        pageSwipe.decrementCurrentIndex();
                        triggered = true;
                    }
                }
            }
        }

        // --- Grid mode, vertical-scroll variant: one continuous list
        // instead of pages, like a normal menu. Reuses appsHarvester's
        // already-flat entries directly (no per-page slicing) in a single
        // AppGridPage, same as how a search category renders.
        //
        // A plain Flickable, not QQC2.ScrollView: ScrollView auto-wraps
        // content in its own internal Flickable and keeps re-asserting its
        // own flickableDirection/boundsBehavior on that inner Flickable
        // whenever geometry changes, silently overwriting anything set from
        // outside (confirmed — three different override attempts via
        // Binding/policy/reparenting on ScrollView.contentItem all had zero
        // effect on the actual drag behavior). Same reasoning as pageSwipe
        // below: build the Flickable directly for full, reliable control,
        // rather than fight a Control's internal one.
        Flickable {
            id: verticalGridArea
            visible: !root.searching && !Plasmoid.configuration.pagedMode
            anchors {
                top: parent.top
                topMargin: view.topArea
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
                horizontalCenter: parent.horizontalCenter
            }
            width: view.gridWidth
            clip: true
            contentWidth: width
            contentHeight: verticalGridPage.height
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                id: verticalScrollBar
                parent: verticalGridArea
                x: verticalGridArea.width - width
                height: verticalGridArea.height
                policy: QQC2.ScrollBar.AsNeeded
                opacity: verticalGridArea.moving || pressed || hovered ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }

            AppGridPage {
                id: verticalGridPage
                width: view.gridWidth
                height: Math.ceil(appsHarvester.entries.length / Math.max(1, view.columns)) * root.cellSize
                entries: appsHarvester.entries
                columns: view.columns
                cellSize: root.cellSize
                iconSize: root.iconSize
                mouseNavActive: view.mouseNavActive

                onActivated: entry => {
                    if (entry.isCommand) {
                        root.runInTerminal(root.query);
                    } else {
                        entry.sourceModel.trigger(entry.modelIndex, "", null);
                    }
                    root.requestClose();
                }
                onContextMenuRequested: (entry, x, y) => {
                    contextMenu.sourceModel = entry.sourceModel;
                    contextMenu.actionList = entry.actionList;
                    contextMenu.favoriteId = entry.favoriteId;
                    contextMenu.pendingIndex = entry.modelIndex;
                    contextMenu.visualParent = verticalGridPage;
                    contextMenu.open(x, y);
                }
            }
        }

        QQC2.PageIndicator {
            visible: !root.searching && Plasmoid.configuration.pagedMode && Plasmoid.configuration.showPageIndicator && pageSwipe.count > 1
            anchors {
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit * 2
                horizontalCenter: parent.horizontalCenter
            }
            count: pageSwipe.count
            currentIndex: pageSwipe.currentIndex
            interactive: true

            onCurrentIndexChanged: {
                if (currentIndex !== pageSwipe.currentIndex) {
                    pageSwipe.setCurrentIndex(currentIndex);
                }
            }
        }

        // --- Search mode: single scrollable results grid ---
        //
        // A plain Flickable, not QQC2.ScrollView: same reasoning as
        // verticalGridArea below (and pageSwipe above) — ScrollView infers
        // scrollable size from a child's implicitWidth/implicitHeight, not
        // width/height, and keeps re-asserting its own defaults on its
        // internal Flickable on geometry changes, both confirmed dead ends
        // in the vertical-scroll layout mode. This one had the exact same
        // bug (a horizontal scrollbar and drag showing up despite content
        // and viewport widths matching) since it was never converted at the
        // same time.
        Flickable {
            id: searchArea
            visible: root.searching
            anchors {
                top: parent.top
                topMargin: view.topArea
                bottom: parent.bottom
                bottomMargin: Kirigami.Units.gridUnit
                horizontalCenter: parent.horizontalCenter
            }
            width: view.gridWidth
            clip: true
            contentWidth: width
            contentHeight: searchResultsView.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                id: searchScrollBar
                parent: searchArea
                x: searchArea.width - width
                height: searchArea.height
                policy: QQC2.ScrollBar.AsNeeded
                opacity: searchArea.moving || pressed || hovered ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }

            SearchResultsView {
                id: searchResultsView
                width: view.gridWidth
                sections: root.searchSections
                columns: view.columns
                cellSize: root.cellSize
                iconSize: root.iconSize
                mouseNavActive: view.mouseNavActive

                onActivated: entry => {
                    if (entry.timer) {
                        root.executable.connectSource(TimerParser.command(entry.timer));
                    } else if (entry.isCommand) {
                        root.runInTerminal(root.query);
                    } else {
                        entry.sourceModel.trigger(entry.modelIndex, "", null);
                    }
                    root.requestClose();
                }
                onContextMenuRequested: (entry, x, y) => {
                    if (entry.timer) {
                        return;
                    }
                    contextMenu.sourceModel = entry.sourceModel;
                    contextMenu.actionList = entry.actionList;
                    contextMenu.favoriteId = entry.favoriteId;
                    contextMenu.pendingIndex = entry.modelIndex;
                    contextMenu.visualParent = searchResultsView;
                    contextMenu.open(x, y);
                }
            }
        }
        } // contentSlide

        ActionMenu {
            id: contextMenu
            property QtObject sourceModel
            property int pendingIndex: -1
            favoritesModel: root.favoritesModel

            onActionClicked: (actionId, actionArgument) => {
                if (actionId === "_favorite_add") {
                    favoritesModel.addFavorite(favoriteId);
                } else if (actionId === "_favorite_remove") {
                    favoritesModel.removeFavorite(favoriteId);
                } else if (actionId === "_toggle_pinned") {
                    togglePinned();
                } else if (sourceModel && pendingIndex >= 0) {
                    const closeRequested = sourceModel.trigger(pendingIndex, actionId, actionArgument);
                    if (closeRequested) {
                        root.requestClose();
                    }
                }
            }
        }
    }
}
