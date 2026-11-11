import QtQuick

// A single fixed page of the GNOME-style app grid: no internal scrolling,
// entries are laid out in a static columns x rows grid.
Item {
    id: page

    property var entries: []
    property int columns: 6
    property int cellSize: 160
    property int iconSize: 96

    // Keyboard-navigation cursor, independent of mouse hover. -1 = nothing
    // selected. Driven by TsunyxDashboard's Keys.onPressed handler (which
    // owns actual focus) and by real mouse movement here, so both stay in
    // sync.
    property int currentIndex: -1

    // Set to false for pages that aren't the "active" one when several
    // AppGridPages are visible at once (SearchResultsView's sections): each
    // page still tracks its own currentIndex, but only the active one should
    // actually show a highlighted item.
    property bool showCursor: true

    // Whether hover is allowed to affect anything at all right now — false
    // right after the dashboard opens, until the mouse has genuinely moved
    // (see TsunyxDashboard.qml). Without this, whatever icon happens to
    // sit under an already-stationary cursor grabs the cursor/highlight.
    property bool mouseNavActive: true

    // entry: {sourceModel, modelIndex, decoration, display, favoriteId, actionList}
    signal activated(var entry)
    signal contextMenuRequested(var entry, real x, real y)

    // Land on the first item whenever this page gets fresh content (a new
    // search, a freshly-harvested "all apps" page) so Enter works right away.
    onEntriesChanged: currentIndex = entries.length > 0 ? 0 : -1

    function activateCurrent() {
        if (currentIndex >= 0 && currentIndex < entries.length) {
            page.activated(entries[currentIndex]);
        }
    }

    implicitWidth: columns * cellSize

    Repeater {
        id: repeater
        model: page.entries

        delegate: AppIconDelegate {
            required property var modelData
            required property int index

            x: (index % page.columns) * page.cellSize
            y: Math.floor(index / page.columns) * page.cellSize
            width: page.cellSize
            height: page.cellSize
            iconSize: page.iconSize

            iconSource: modelData.decoration
            label: modelData.display
            current: page.showCursor && index === page.currentIndex
            mouseNavActive: page.mouseNavActive

            onMouseMoved: if (page.mouseNavActive) page.currentIndex = index;
            onActivated: page.activated(modelData)
            onContextMenuRequested: (mx, my) => {
                const global = mapToItem(page, mx, my);
                page.contextMenuRequested(modelData, global.x, global.y);
            }
        }
    }
}
