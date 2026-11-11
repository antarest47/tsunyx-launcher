import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

// Lightweight context menu: shows an entry's own actionList (from
// Kicker.RootModel, e.g. "Uninstall", "Add to Desktop") plus a simple
// favorite toggle and pinning to the panel's task manager. Built fresh each time actionList/favoriteId changes.
Item {
    id: root

    property Item visualParent
    property var actionList: []
    property QtObject favoritesModel: null
    property var favoriteId: null

    signal actionClicked(string actionId, var actionArgument)

    readonly property var taskManagers: ["org.uzunyx.tasks", "org.kde.plasma.taskmanager", "org.kde.plasma.icontasks"]

    function taskManagerApplet() {
        const applets = Plasmoid.containment ? Plasmoid.containment.applets : [];
        for (let i = 0; i < applets.length; i++) {
            if (taskManagers.indexOf(applets[i].pluginName) >= 0) {
                return applets[i];
            }
        }
        return null;
    }

    function launcherUrl() {
        const id = String(favoriteId).replace(/^applications:/, "");
        return id.endsWith(".desktop") ? "applications:" + id : "";
    }

    // Kept in the task manager's own config, which it follows. pinnedModel
    // knows that Dolphin is the pinned preferred://filemanager, for example.
    function togglePinned() {
        const applet = taskManagerApplet();
        if (!applet) {
            return;
        }
        pinnedModel.launcherList = applet.configuration.launchers;
        if (pinnedModel.launcherPosition(launcherUrl()) >= 0) {
            pinnedModel.requestRemoveLauncher(launcherUrl());
        } else {
            pinnedModel.requestAddLauncher(launcherUrl());
        }
        applet.configuration.launchers = pinnedModel.launcherList;
    }

    TaskManager.TasksModel {
        id: pinnedModel
    }

    // Open, or on its way: the dashboard loses the focus to it and must stay.
    readonly property bool shown: menu.status !== PlasmaExtras.Menu.Closed

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

        const applet = taskManagerApplet();
        if (applet && launcherUrl() !== "") {
            pinnedModel.launcherList = applet.configuration.launchers;
            const pinned = pinnedModel.launcherPosition(launcherUrl()) >= 0;
            const domain = "plasma_applet_org.kde.plasma.taskmanager";
            menu.addMenuItem(itemComponent.createObject(menu, {
                "actionItem": {
                    "text": pinned ? i18ndc(domain, "action:inmenu", "Unpin from Task Manager")
                                   : i18ndc(domain, "action:inmenu", "&Pin to Task Manager"),
                    "icon": pinned ? "window-unpin" : "window-pin",
                    "actionId": "_toggle_pinned"
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
