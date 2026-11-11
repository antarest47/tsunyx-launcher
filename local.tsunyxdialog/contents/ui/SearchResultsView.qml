import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Search results laid out as a vertical stack of labeled sections (one per
// runner category: Applications, Files, Web Bookmarks, etc.), each its own
// small AppGridPage. Owns its own keyboard-navigation cursor across
// sections, since a plain AppGridPage only knows about one flat entries list.
Item {
    id: view

    // [{label, entries: [...]}]
    property var sections: []
    property int columns: 6
    property int cellSize: 160
    property int iconSize: 96

    property int currentSection: 0
    property bool mouseNavActive: true

    signal activated(var entry)
    signal contextMenuRequested(var entry, real x, real y)

    implicitWidth: columns * cellSize
    implicitHeight: column.implicitHeight

    onSectionsChanged: currentSection = 0

    function currentPage() {
        if (currentSection < 0 || currentSection >= repeater.count) {
            return null;
        }
        const d = repeater.itemAt(currentSection);
        return d ? d.gridPage : null;
    }

    function activateCurrent() {
        const p = currentPage();
        if (p) {
            p.activateCurrent();
        }
    }

    // Top/bottom of the currently-selected icon's cell, in this Item's own
    // coordinate space — used by TsunyxDashboard.qml to scroll the
    // containing Flickable so keyboard navigation never lands outside the
    // visible viewport. mapToItem instead of hand-adding up section
    // heights/spacing/labels: it accounts for all of that (and the
    // ColumnLayout's own positioning) for free.
    function currentItemBounds() {
        const p = currentPage();
        if (!p || p.currentIndex < 0 || p.entries.length === 0) {
            return null;
        }
        const cols = Math.max(1, p.columns);
        const row = Math.floor(p.currentIndex / cols);
        const top = p.mapToItem(view, 0, row * p.cellSize).y;
        return { top: top, bottom: top + p.cellSize };
    }

    function moveHorizontal(delta) {
        const p = currentPage();
        if (!p || p.entries.length === 0) {
            return;
        }
        if (p.currentIndex < 0) {
            p.currentIndex = 0;
            return;
        }
        const next = p.currentIndex + delta;
        if (next >= 0 && next < p.entries.length) {
            p.currentIndex = next;
        }
    }

    function moveVertical(delta) {
        const p = currentPage();
        if (!p || p.entries.length === 0) {
            return;
        }
        const cols = Math.max(1, p.columns);
        if (p.currentIndex < 0) {
            p.currentIndex = 0;
            return;
        }
        const col = p.currentIndex % cols;
        const next = p.currentIndex + delta * cols;
        if (next >= 0 && next < p.entries.length) {
            p.currentIndex = next;
            return;
        }
        // Fell off the top/bottom edge of this section's grid: hop to the
        // adjacent section, landing in roughly the same column.
        if (delta > 0 && currentSection < repeater.count - 1) {
            currentSection += 1;
            const np = currentPage();
            if (np && np.entries.length > 0) {
                np.currentIndex = Math.min(col, np.entries.length - 1);
            }
        } else if (delta < 0 && currentSection > 0) {
            currentSection -= 1;
            const np = currentPage();
            if (np && np.entries.length > 0) {
                const npCols = Math.max(1, np.columns);
                const lastRowStart = Math.floor((np.entries.length - 1) / npCols) * npCols;
                np.currentIndex = Math.min(lastRowStart + col, np.entries.length - 1);
            }
        }
    }

    ColumnLayout {
        id: column
        width: view.width
        spacing: Kirigami.Units.largeSpacing * 1.5

        Repeater {
            id: repeater
            model: view.sections

            delegate: ColumnLayout {
                id: sectionDelegate
                required property var modelData
                required property int index
                property alias gridPage: gridPageItem

                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Text {
                    Layout.leftMargin: Kirigami.Units.smallSpacing
                    text: sectionDelegate.modelData.label
                    color: "white"
                    opacity: 0.7
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                }

                AppGridPage {
                    id: gridPageItem
                    entries: sectionDelegate.modelData.entries
                    columns: view.columns
                    cellSize: view.cellSize
                    iconSize: view.iconSize
                    showCursor: sectionDelegate.index === view.currentSection
                    mouseNavActive: view.mouseNavActive
                    implicitWidth: view.columns * view.cellSize
                    implicitHeight: Math.ceil(entries.length / Math.max(1, columns)) * cellSize

                    onActivated: entry => view.activated(entry)
                    onContextMenuRequested: (entry, x, y) => view.contextMenuRequested(entry, x, y)
                }
            }
        }
    }
}
