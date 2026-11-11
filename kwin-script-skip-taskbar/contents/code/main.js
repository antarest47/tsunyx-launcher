// Tsunyx Launcher sets its dashboard window's title to exactly this string
// (TsunyxDashboard.qml) once it's shown for the first time. Matching by
// title is the only reliable option since the window runs inside
// plasmashell's own process, sharing its resourceClass with every other
// Plasma popup.
var TITLE = "Tsunyx Launcher";
// Set by requestClose() in TsunyxDashboard.qml when the close animation
// starts; the plain TITLE comes back when the launcher is opened again.
var CLOSING_TITLE = "Tsunyx Launcher (closing)";
// Magic lamp mode (lampAnimation option): the Genie Anywhere KWin effect
// animates the window opening and closing, so it isn't faded here and stays
// opaque. The title goes on with the panel button's position for the effect
// ("Tsunyx Launcher (lamp) 652,1172").
var LAMP_TITLE = "Tsunyx Launcher (lamp)";

function isLamp(window) {
    return window.caption.startsWith(LAMP_TITLE);
}

function isOurWindow(window) {
    return window.caption === TITLE || window.caption === CLOSING_TITLE || isLamp(window);
}

function stopFade(window) {
    const fade = fades.get(window);
    if (fade) {
        fade.stop();
        fades.delete(window);
    }
}

// Kicker.DashboardWindow hides itself from the taskbar via a Wayland-only
// call (KWayland::Client::PlasmaShellSurface::setSkipTaskbar) that's only
// exercised along its own true-fullscreen path. The launcher's
// "keep panel visible" option forces the window out of that fullscreen
// state (see TsunyxDashboard.qml), which loses that hint. Re-asserting
// skipTaskbar/skipPager/skipSwitcher here, from the compositor side, isn't
// tied to that internal path at all, so it isn't affected by whatever
// fullscreen/maximized transitions the window goes through afterward.
function enforce(window) {
    if (!isOurWindow(window)) {
        return;
    }
    window.skipTaskbar = true;
    window.skipPager = true;
    window.skipSwitcher = true;
}

// The launcher asks to be maximized so it stays in the normal window layer,
// below the panel. But the maximize area excludes every reserved strut, not
// just the panel's (e.g. screen-edge margins), so it can come out smaller
// than the screen. Instead, turn it into a normal window covering the whole
// screen: still in the normal layer, so an "Always Visible" panel is drawn
// on top of the launcher's background, like GNOME's dash over its app grid.
const busy = new Set();

function coverScreen(window) {
    if (!isOurWindow(window) || busy.has(window)) {
        return;
    }
    const area = workspace.clientArea(KWin.FullScreenArea, window);
    const f = window.frameGeometry;
    if (window.maximizeMode === 0 && f.x === area.x && f.y === area.y
            && f.width === area.width && f.height === area.height) {
        return;
    }
    busy.add(window);
    if (window.maximizeMode !== 0) {
        window.setMaximize(false, false);
    }
    window.frameGeometry = { x: area.x, y: area.y, width: area.width, height: area.height };
    busy.delete(window);
}

// Kicker.DashboardWindow always enables KWin's blur behind its whole window,
// and the launcher's own fade only covers its dim color, so the blur stayed
// at full strength until the window was hidden, then vanished at once. KWin
// draws the blur with the window's opacity, so fading the opacity here fades
// the blur too. It's timed with the icons' flight (revealDuration, 500 ms, in
// TsunyxDashboard.qml): on open it fades in over the first 300 ms; on close
// it waits, then fades out over the last part, so the icons don't vanish
// before they get back to the panel button.
const FADE_DURATION = 300;
const CLOSE_FADE_DELAY = 220;
const CLOSE_FADE_DURATION = 280;
const FADE_INTERVAL = 16;
const fades = new Map();

function fadeTo(window, target, duration = FADE_DURATION) {
    const previous = fades.get(window);
    if (previous) {
        previous.stop();
    }
    const from = window.opacity;
    const started = Date.now();
    const timer = new QTimer();
    timer.interval = FADE_INTERVAL;
    timer.timeout.connect(() => {
        const t = Math.min(1, (Date.now() - started) / duration);
        const eased = 1 - Math.pow(1 - t, 3); // Easing.OutCubic
        window.opacity = from + (target - from) * eased;
        if (t >= 1) {
            timer.stop();
            fades.delete(window);
        }
    });
    fades.set(window, timer);
    timer.start();
}

function followCaption(window) {
    if (isLamp(window)) {
        stopFade(window);
        window.opacity = 1;
    } else if (window.caption === CLOSING_TITLE) {
        const previous = fades.get(window);
        if (previous) {
            previous.stop();
        }
        const delay = new QTimer();
        delay.singleShot = true;
        delay.interval = CLOSE_FADE_DELAY;
        delay.timeout.connect(() => {
            if (window.caption === CLOSING_TITLE) {
                fadeTo(window, 0, CLOSE_FADE_DURATION);
            }
        });
        fades.set(window, delay);
        delay.start();
    } else if (window.caption === TITLE) {
        // Opening: start from transparent, then fade in.
        window.opacity = 0;
        fadeTo(window, 1);
    }
}

function setup(window) {
    enforce(window);
    window.captionChanged.connect(() => coverScreen(window));
    window.maximizedChanged.connect(() => coverScreen(window));
    coverScreen(window);
    // The window is destroyed on close and created again on every open,
    // usually already carrying its title: fade it in from here. If it still
    // has the closing title from last time, keep it invisible until the
    // launcher's QML sets the plain one (followCaption fades it in then).
    if (window.caption === TITLE) {
        window.opacity = 0;
        fadeTo(window, 1);
    } else if (window.caption === CLOSING_TITLE) {
        window.opacity = 0;
    }
    window.captionChanged.connect(() => followCaption(window));
    window.closed.connect(() => stopFade(window));
    // The title may only be set a moment after the window is first mapped
    // (it happens once the launcher's own QML runs its onVisibleChanged),
    // so re-check whenever it changes instead of only once at creation.
    window.captionChanged.connect(() => enforce(window));
    // Guards against anything (KWin itself, or Kicker's own internal
    // fullscreen-state handling) clearing these flags later.
    window.skipTaskbarChanged.connect(() => enforce(window));
}

workspace.windowAdded.connect(setup);
workspace.windowList().forEach(setup);
