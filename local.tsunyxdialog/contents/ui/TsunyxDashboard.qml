import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker

// Fixed-size, custom-bordered popup variant: a real top-level window, but
// built on PlasmaCore.Dialog instead of Kicker.DashboardWindow. Dialog gives
// us none of DashboardWindow's fullscreen/dim-background/keyboard-proxy
// conveniences, but also none of its fights over size/position/visibility —
// see tsunyx_architecture_notes memory for why the earlier attempt at
// rebuilding on Dialog/AppletPopup for a FULLSCREEN window was abandoned.
// This is a fundamentally different goal (a small fixed-size floating
// window), which sidesteps that dead end entirely: backgroundHints:
// NoBackground turns off Dialog's own frame/background drawing, and
// borderFrame below paints our own black-fill + blue-border look by hand
// instead of relying on real KWin/Aurorae decoration (confirmed live that
// Dialog never receives one, no matter what "type" is set to — a plain
// QtQuick.Window does, but Dialog fundamentally forces frameless window
// flags under the hood).
PlasmaCore.Dialog {
    id: root

    // A stable, unique title so the companion KWin script (see
    // kwin-script-tsunyxdialog/ at repo root) can find this window to
    // center it and hide it from the taskbar/pager/switcher — both are
    // things a Wayland client cannot do to itself for a plain toplevel
    // window (confirmed live: explicit x/y bindings here are silently
    // ignored, since xdg_toplevel surfaces don't let clients position
    // themselves; only the compositor/WM can, hence the KWin script).
    title: "Tsunyx Launcher Dialog"
    type: PlasmaCore.Dialog.Normal
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.FramelessWindowHint | Qt.Window
    // Closing on focus loss is Dialog's own built-in equivalent of the old
    // click-outside-to-close background MouseArea.
    hideOnWindowDeactivate: true

    // Fixed physical size, per explicit user choice (a fixed-size custom
    // border image/rectangle only looks right at one size). Just an initial
    // guess here — dividing by Screen.devicePixelRatio looked right in
    // principle, but confirmed live that this attached property reads back
    // 2 on this machine's 110% display scale (Qt Quick rounds a fractional
    // Wayland output scale to the nearest integer for it), not the real
    // 1.1 that actually maps logical-to-physical pixels. The companion KWin
    // script (kwin-script-tsunyxdialog/) does the authoritative physical
    // -pixel-accurate sizing from the compositor side, using its own
    // correctly-fractional Screen.devicePixelRatio, and overrides whatever
    // this evaluates to — so all this needs to be is a reasonable initial
    // size before that correction lands (also keeps it comfortably under
    // Dialog's own max-size clamp, since this machine's logical screen
    // height is only ~982px and a raw 990 would already exceed that).
    readonly property int targetWidth: 1490
    readonly property int targetHeight: 990
    width: targetWidth / 1.5
    height: targetHeight / 1.5

    property QtObject rootModel
    property QtObject runnerModel
    property QtObject favoritesModel
    property QtObject allAppsModel: null

    readonly property int iconSize: Plasmoid.configuration.iconSize
    readonly property int cellSize: iconSize + Kirigami.Units.gridUnit * 3
    readonly property bool searching: hiddenSearchInput.text !== ""
    readonly property int borderWidth: 2

    // 0 = fully hidden state (content off the bottom edge, invisible), 1 =
    // fully revealed. Driven to 1 right after opening and back to 0 on
    // close, with the Behavior below providing the actual slide motion —
    // see requestClose()/requestToggle(). No separate background-fade
    // progress this time: unlike the old fullscreen dim-the-whole-desktop
    // background, there's no backdrop to dim here, just our own fixed-size
    // bordered box, so one progress value covers the whole open/close
    // animation.
    property real revealProgress: 0
    readonly property int revealDuration: 280
    property bool closing: false

    Behavior on revealProgress {
        NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutCubic }
    }

    // Dialog's own toggle()/hide() equivalents: unlike
    // Kicker.DashboardWindow, Dialog doesn't provide toggle()/hide() itself,
    // just a plain "visible" property.
    function toggle() {
        root.visible = !root.visible;
    }
    function hide() {
        root.visible = false;
    }

    // Plays the slide-down exit animation first, then actually hides once
    // it's done. Every internal close (Escape, launching an app, a
    // favorite-menu action that requests closing) goes through
    // requestClose(), and CompactRepresentation.qml calls requestToggle()
    // instead of toggle() for the same reason.
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
        closing = true;
        revealProgress = 0;
        closeTimer.restart();
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
            reset();
            view.forceActiveFocus();
            // Already 0 at this point (closeTimer only flips the window
            // invisible after finishing the animation back down), so this
            // triggers the entrance Behavior: slide up.
            revealProgress = 1;
        }
    }

    Component.onCompleted: findAllAppsModel()

    mainItem: Item {
        id: view
        width: root.width
        height: root.height
        focus: true

        // Our stand-in for real window decoration — see the file-level
        // comment above for why Dialog can't get a real Aurorae border.
        // Plain solid color + border instead of trying to reuse
        // Borderline's own Aurorae SVG assets, which are designed for
        // Aurorae's own tinting/compositing engine, not for being dropped
        // into arbitrary QML as a static image.
        Rectangle {
            id: borderFrame
            anchors.fill: parent
            color: "black"
            border.color: "#3daee9"
            border.width: root.borderWidth
            radius: 6
        }

        // computed grid geometry — width/height here need to exclude the
        // borderFrame's own thickness, since the actual content
        // (contentSlide below) is inset by root.borderWidth on every side
        // so nothing draws on top of the blue border.
        readonly property int topArea: Kirigami.Units.gridUnit * 8
        readonly property int bottomArea: Kirigami.Units.gridUnit * 4
        readonly property int columns: Math.max(1, Math.floor((width - 2 * root.borderWidth) / root.cellSize))
        readonly property int rows: Math.max(1, Math.floor((height - 2 * root.borderWidth - topArea - bottomArea) / root.cellSize))
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

        // PlasmaCore.Dialog's mainItem, like Kicker.DashboardWindow's, only
        // accepts a single Item child directly (a Timer placed at the top
        // level under the Dialog itself failed the whole component with
        // "Cannot assign object of type Timer to property of type
        // QQuickItem*" — confirmed live). Belongs here instead, since
        // "view" is a plain Item.
        Timer {
            id: closeTimer
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
            // No onKeyEscapePressed here (that was a Kicker.DashboardWindow
            // signal) — handled as a plain key case instead.
            if (event.key === Qt.Key_Escape) {
                if (root.searching) {
                    hiddenSearchInput.text = "";
                } else {
                    root.requestClose();
                }
                event.accepted = true;
                return;
            }

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
                    searchResultsView.activateCurrent();
                    event.accepted = true;
                    break;
                }
                if (event.accepted) {
                    ensureSearchCurrentVisible();
                }
            } else {
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

                if (!paged && event.accepted) {
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

            if (event.accepted) {
                return;
            }

            // Fallback for everything above that didn't match: replicates
            // just enough of Kicker.DashboardWindow's keyEventProxy
            // (unhandled key events fed straight into hiddenSearchInput at
            // the window level — PlasmaCore.Dialog has no equivalent) to
            // let typing anywhere start/continue a search. Append/backspace
            // only, no text-cursor movement — arrow keys are already fully
            // claimed above for grid/search navigation.
            if (event.key === Qt.Key_Backspace) {
                hiddenSearchInput.text = hiddenSearchInput.text.slice(0, -1);
                event.accepted = true;
            } else if (event.text.length > 0 && event.text >= " ") {
                hiddenSearchInput.text += event.text;
                event.accepted = true;
            }
        }

        // hideOnWindowDeactivate covers "click elsewhere on the desktop to
        // close"; this just covers clicking the empty padding inside our
        // own border but outside the actual grid/search content.
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: if (!root.searching) root.requestClose();
        }

        // Real text input: kept invisible. Its onTextChanged drives the
        // search; a fallback case in Keys.onPressed below forwards
        // printable keystrokes into it so typing anywhere in the grid
        // starts a search without having to click into a field first
        // (matches GNOME) — Kicker.DashboardWindow's keyEventProxy gave us
        // this for free, PlasmaCore.Dialog has no equivalent.
        TextInput {
            id: hiddenSearchInput
            width: 0
            height: 0
            visible: false
            persistentSelection: true

            onTextChanged: {
                if (root.runnerModel) {
                    root.runnerModel.query = text;
                }
            }
        }

        // Everything the user actually looks at (search pill, grid, page
        // dots, search results) lives in here instead of directly in
        // "view", so it can be slid up/down as one block on open/close
        // without disturbing the full-size background click-catcher, hidden
        // search input, or the mouse-position baseline tracker above, none
        // of which should move. Inset by root.borderWidth on every side so
        // nothing draws on top of borderFrame's blue border, and clipped so
        // the slide-in animation doesn't spill past the rounded corners.
        Item {
            id: contentSlide
            clip: true
            x: root.borderWidth
            width: view.width - 2 * root.borderWidth
            height: view.height - 2 * root.borderWidth
            // Full height, so icons genuinely travel from below the visible
            // area on open/close.
            y: root.borderWidth + (1 - root.revealProgress) * height

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
            sourceModel: (hiddenSearchInput.text !== "" && root.runnerModel) ? root.runnerModel : null
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
                    entry.sourceModel.trigger(entry.modelIndex, "", null);
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
                sections: searchHarvester.sections
                columns: view.columns
                cellSize: root.cellSize
                iconSize: root.iconSize
                mouseNavActive: view.mouseNavActive

                onActivated: entry => {
                    entry.sourceModel.trigger(entry.modelIndex, "", null);
                    root.requestClose();
                }
                onContextMenuRequested: (entry, x, y) => {
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
