// Tsunyx Launcher (Dialog) sets its window's title to exactly this string
// (TsunyxDashboard.qml) as a static QML property, so it's already set by
// the time the window is first mapped. Matching by title is the only
// reliable option since the window runs inside plasmashell's own process,
// sharing its resourceClass with every other Plasma popup.
var TITLE = "Tsunyx Launcher Dialog";

// The user wants a fixed PHYSICAL-pixel size regardless of display scale.
// Must match TsunyxDashboard.qml's targetWidth/targetHeight.
var TARGET_PHYSICAL_WIDTH = 1490;
var TARGET_PHYSICAL_HEIGHT = 990;

// Guards against resizeAndCenter()'s own frameGeometry write re-entering
// itself via the frameGeometryChanged connection below.
var repositioning = false;

function isOurWindow(window) {
    return window.caption === TITLE;
}

// Confirmed live (on this machine's 110% display scale) that QML's own
// "Screen.devicePixelRatio" attached property reads back 2, not 1.1 — Qt
// Quick apparently rounds a fractional Wayland output scale to the nearest
// integer for that property, which is meant for backing-store/rendering
// resolution, not for the compositor's actual logical-coordinate scale.
// KWin's own Screen.devicePixelRatio (workspace.screens[i]) doesn't have
// that problem and matches kscreen-doctor's real output Scale exactly
// (confirmed live: both read 1.1) — hence doing the physical-size
// conversion here instead of in TsunyxDashboard.qml.
function outputScale() {
    return workspace.screens.length > 0 ? workspace.screens[0].devicePixelRatio : 1;
}

// PlasmaCore.Dialog is a real toplevel (xdg_toplevel) window on Wayland, and
// clients cannot position their own toplevel surfaces — confirmed live: an
// explicit x/y binding in TsunyxDashboard.qml is silently ignored. A client
// CAN request its own size, but only in its own (unreliable, see above)
// notion of logical pixels, not physical ones — so both position and the
// final physical-size correction are done here instead, from the
// compositor side, in one frameGeometry write.
function resizeAndCenter(window) {
    if (repositioning) {
        return;
    }
    const scale = outputScale();
    const width = Math.round(TARGET_PHYSICAL_WIDTH / scale);
    const height = Math.round(TARGET_PHYSICAL_HEIGHT / scale);
    const area = workspace.clientArea(KWin.PlacementArea, window);
    const x = Math.round(area.x + (area.width - width) / 2);
    const y = Math.round(area.y + (area.height - height) / 2);
    const geo = window.frameGeometry;
    if (geo.x === x && geo.y === y && geo.width === width && geo.height === height) {
        return;
    }
    repositioning = true;
    window.frameGeometry = { x: x, y: y, width: width, height: height };
    repositioning = false;
}

// Same reasoning as the plain Tsunyx Launcher's skip-taskbar script: this
// window has no real KWin decoration or Wayland-only hint of its own to
// hide itself from the taskbar/pager/switcher (see
// tsunyx_architecture_notes memory), so it's asserted here instead.
function enforceSkip(window) {
    window.skipTaskbar = true;
    window.skipPager = true;
    window.skipSwitcher = true;
}

function setup(window) {
    if (!isOurWindow(window)) {
        return;
    }
    resizeAndCenter(window);
    enforceSkip(window);
    // Defensive re-assertion: guards against anything (KWin itself, or
    // PlasmaCore.Dialog's own internal layout-update methods, which run on
    // every show given the "type: Normal" Dialog re-runs its own
    // min/max-size bookkeeping — see TsunyxDashboard.qml) resetting either
    // property later, e.g. each time the window is re-shown after being
    // hidden rather than destroyed.
    window.frameGeometryChanged.connect(() => resizeAndCenter(window));
    window.skipTaskbarChanged.connect(() => enforceSkip(window));
}

workspace.windowAdded.connect(setup);
workspace.windowList().forEach(setup);
