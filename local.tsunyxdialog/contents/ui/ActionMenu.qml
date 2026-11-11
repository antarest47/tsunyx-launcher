import QtQuick
import org.kde.plasma.extras as PlasmaExtras

// Lightweight context menu: shows an entry's own actionList (from
// Kicker.RootModel, e.g. "Uninstall", "Add to Desktop") plus a simple
// favorite toggle. Built fresh each time actionList/favoriteId changes.
Item {
    id: root

    property Item visualParent
    property var actionList: []
    property QtObject favoritesModel: null
    property var favoriteId: null

    signal actionClicked(string actionId, var actionArgument)

    function open(x, y) {
        rebuild();
        if (x !== undefined && y !== undefined) {
            menu.open(x, y);
        } else {
            menu.open();
        }
    }

    function rebuild() {
        menu.clearMenuItems();

        (actionList || []).forEach(item => {
            menu.addMenuItem(itemComponent.createObject(menu, {
                "actionItem": item
            }));
        });

        if (favoritesModel && favoriteId !== null && favoriteId !== undefined) {
            if (actionList && actionList.length > 0) {
                menu.addMenuItem(itemComponent.createObject(menu, {
                    "actionItem": { "type": "separator" }
                }));
            }

            const isFav = favoritesModel.isFavorite(favoriteId);
            menu.addMenuItem(itemComponent.createObject(menu, {
                "actionItem": {
                    "text": isFav ? i18n("Remove from Favorites") : i18n("Add to Favorites"),
                    "icon": isFav ? "bookmark-remove" : "bookmark-new",
                    "actionId": isFav ? "_favorite_remove" : "_favorite_add"
                }
            }));
        }
    }

    PlasmaExtras.Menu {
        id: menu
        visualParent: root.visualParent
    }

    Component {
        id: itemComponent

        // "type": "separator" -> a plain divider line, not clickable.
        // "type": "title" -> a non-clickable section header (e.g. "Recent Files").
        // Anything else is a normal action. Kicker's actionList entries use
        // exactly this convention (see how kicker's own ActionMenu-equivalent
        // and FairyWren's contextMenuItemComponent both branch on it) —
        // treating every entry as a plain clickable item, as the first version
        // of this file did, rendered separators/headers as blank clickable
        // rows that fell through to triggering the app's default action.
        PlasmaExtras.MenuItem {
            property var actionItem
            text: actionItem.text || ""
            icon: actionItem.icon || null
            enabled: actionItem.type !== "title" && (("enabled" in actionItem) ? actionItem.enabled : true)
            separator: actionItem.type === "separator"
            section: actionItem.type === "title"
            onClicked: root.actionClicked(actionItem.actionId, actionItem.actionArgument)
        }
    }
}
