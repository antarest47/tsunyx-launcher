import QtQuick

// Flattens a Kicker app/runner sub-model into a plain JS array of
// {modelIndex, decoration, display, favoriteId, actionList} objects, so it
// can be chunked into fixed-size GNOME-style pages. QAbstractItemModel has
// no slicing API, so we harvest role data through a throwaway Repeater and
// read it back via Repeater.itemAt() once all delegates have landed.
Item {
    id: harvester

    property var sourceModel: null
    property var entries: []

    signal rebuilt()

    onSourceModelChanged: rebuildTimer.restart()

    Repeater {
        id: probe

        model: harvester.sourceModel

        delegate: Item {
            id: probeDelegate
            required property int index
            required property var decoration
            required property var display
            required property var favoriteId
            required property var actionList
        }

        onCountChanged: rebuildTimer.restart()
    }

    Timer {
        id: rebuildTimer
        // Debounced rather than interval: 0, so a burst of countChanged
        // signals (e.g. while typing a search query) coalesces into one
        // rebuild and always yields the event loop between attempts.
        interval: 75
        onTriggered: {
            const list = [];
            for (let i = 0; i < probe.count; i++) {
                const item = probe.itemAt(i);
                if (!item) {
                    continue;
                }
                list.push({
                    sourceModel: harvester.sourceModel,
                    modelIndex: i,
                    decoration: item.decoration,
                    display: item.display,
                    favoriteId: item.favoriteId,
                    actionList: item.actionList
                });
            }
            harvester.entries = list;
            harvester.rebuilt();
        }
    }
}
