import QtQuick

// Search results, kept categorized by runner (Applications, Files, Web
// Bookmarks, etc.) instead of merged into one flat list. Requires
// runnerModel.mergeResults = false (set in main.qml) so runnerModel itself
// exposes one row per category, each with its own modelForRow(i).description
// label — same two-level shape as the "all apps" model handled by
// GroupedAppsHarvester.qml, except here the per-category label is kept
// instead of discarded. Uses the same single-debounced-timer design as
// GroupedAppsHarvester/ModelHarvester — see [[plasma_widget_dev_caution]] in
// memory for why that matters.
Item {
    id: root

    property var sourceModel: null
    // Bind this to the live search text: modelForRow(i) must be re-fetched
    // on every keystroke (its result isn't a self-updating live view — see
    // how kicker/FairyWren's own SearchList.qml does
    // "onQueryChanged: searchList.model = runnerModel.modelForRow(0)" on
    // every change instead of fetching once). Without this, results froze
    // at whatever (usually nothing) existed the instant search mode opened.
    property string refreshKey: ""
    // [{label, entries: [{sourceModel, modelIndex, decoration, display, favoriteId, actionList}]}]
    property var sections: []

    onSourceModelChanged: rebuildTimer.restart()
    onRefreshKeyChanged: rebuildTimer.restart()

    Repeater {
        id: rowsProbe
        model: root.sourceModel

        delegate: Item {
            id: rowItem
            required property int index

            // Reading root.refreshKey here (even though the value itself is
            // unused) makes this binding re-evaluate — and re-call
            // modelForRow() — every time the search text changes.
            property QtObject rowModel: (root.refreshKey, root.sourceModel) ? root.sourceModel.modelForRow(index) : null
            property string label: rowModel ? rowModel.description : ""
            property alias innerCount: innerProbe.count

            function itemAt(i) {
                return innerProbe.itemAt(i);
            }

            onInnerCountChanged: rebuildTimer.restart()

            Repeater {
                id: innerProbe
                model: rowItem.rowModel

                delegate: Item {
                    required property int index
                    required property var decoration
                    required property var display
                    required property var favoriteId
                    required property var actionList
                }
            }
        }

        onCountChanged: rebuildTimer.restart()
    }

    Timer {
        id: rebuildTimer
        interval: 75
        onTriggered: {
            const result = [];
            for (let r = 0; r < rowsProbe.count; r++) {
                const rowItem = rowsProbe.itemAt(r);
                if (!rowItem || rowItem.innerCount === 0) {
                    continue;
                }
                const entries = [];
                for (let i = 0; i < rowItem.innerCount; i++) {
                    const it = rowItem.itemAt(i);
                    if (!it) {
                        continue;
                    }
                    entries.push({
                        sourceModel: rowItem.rowModel,
                        modelIndex: i,
                        decoration: it.decoration,
                        display: it.display,
                        favoriteId: it.favoriteId,
                        actionList: it.actionList
                    });
                }
                if (entries.length > 0) {
                    result.push({ label: rowItem.label, entries: entries });
                }
            }
            root.sections = result;
        }
    }
}
