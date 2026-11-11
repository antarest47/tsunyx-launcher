import QtQuick

// Kicker's merged "all applications" model (the KICKER_ALL_MODEL row) is not
// a flat list of apps: it's a list of alphabetic groups, each of which needs
// its own modelForRow() to reach the real app entries (see how kicker's own
// ItemMultiGridView.qml drills into "repeater.model.modelForRow(index)" per
// group). This flattens that two-level structure into one merged, ungrouped
// GNOME-style list.
//
// Previous version nested one full ModelHarvester component (its own
// Repeater + zero-interval Timer) per group. With ~20 alphabetic groups that
// meant ~20 independently-restarting timers whose completions fed back into
// each other via bound properties, and on this machine that cascade pegged
// plasmashell's main thread hard enough to freeze the whole panel and every
// global shortcut. This version uses a SINGLE debounced timer for the whole
// two-level structure: any group's row count changing just postpones the one
// pending rebuild instead of kicking off its own independent chain.
Item {
    id: root

    property var groupsModel: null
    property var entries: []

    onGroupsModelChanged: rebuildTimer.restart()

    Repeater {
        id: groupsProbe
        model: root.groupsModel

        delegate: Item {
            id: groupItem
            required property int index

            property QtObject innerModel: root.groupsModel ? root.groupsModel.modelForRow(index) : null
            property alias innerCount: innerProbe.count

            function itemAt(i) {
                return innerProbe.itemAt(i);
            }

            onInnerCountChanged: rebuildTimer.restart()

            Repeater {
                id: innerProbe
                model: groupItem.innerModel

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
        // Debounced (not interval: 0): coalesces bursts of row-count churn
        // into one pass, and guarantees the event loop gets to breathe
        // between rebuilds no matter how often something restarts us.
        interval: 75
        onTriggered: {
            const merged = [];
            for (let g = 0; g < groupsProbe.count; g++) {
                const groupItem = groupsProbe.itemAt(g);
                if (!groupItem) {
                    continue;
                }
                const innerModel = groupItem.innerModel;
                for (let i = 0; i < groupItem.innerCount; i++) {
                    const it = groupItem.itemAt(i);
                    if (!it) {
                        continue;
                    }
                    merged.push({
                        sourceModel: innerModel,
                        modelIndex: i,
                        decoration: it.decoration,
                        display: it.display,
                        favoriteId: it.favoriteId,
                        actionList: it.actionList
                    });
                }
            }
            root.entries = merged;
        }
    }
}
