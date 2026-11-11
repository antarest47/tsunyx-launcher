// Timers from the search boxes, the same file in Tsunyx Launcher and Tsunyx
// Search (uzunyx-timer runs them, uzunyx-clock shows them).
.pragma library

const UNITS = { h: 3600, hs: 3600, hora: 3600, horas: 3600,
                m: 60, min: 60, mins: 60, minuto: 60, minutos: 60,
                s: 1, seg: 1, segs: 1, segundo: 1, segundos: 1 };
const MAX_SECONDS = 24 * 3600;

// "5m", "1h 30m te", "temporizador 10 pizza" (with the word, a bare number
// means minutes) give {seconds, label, forced, text}; anything else, null.
// Without the word (not forced) it gives way to a result of that name.
function parse(input) {
    const word = /^(?:temporizador|timer)\s+(.*)$/i.exec(input.trim());
    let rest = word ? word[1] : input.trim();
    let seconds = 0;
    let match;
    while ((match = /^(\d+)\s*([a-z]+)(?=[\s\d]|$)\s*/i.exec(rest)) && UNITS[match[2].toLowerCase()]) {
        seconds += parseInt(match[1]) * UNITS[match[2].toLowerCase()];
        rest = rest.slice(match[0].length);
    }
    if (seconds === 0 && word && (match = /^(\d+)(?:\s+|$)/.exec(rest))) {
        seconds = parseInt(match[1]) * 60;
        rest = rest.slice(match[0].length);
    }
    if (seconds <= 0 || seconds > MAX_SECONDS) {
        return null;
    }
    const parts = [];
    if (seconds >= 3600) parts.push(Math.floor(seconds / 3600) + " h");
    if (seconds % 3600 >= 60) parts.push(Math.floor(seconds % 3600 / 60) + " min");
    if (seconds % 60 > 0) parts.push(seconds % 60 + " s");
    return { seconds: seconds, label: rest.replace(/^de\s+/i, "").trim(), forced: word !== null, text: parts.join(" ") };
}

function command(timer) {
    return "uzunyx-timer start " + timer.seconds + " '" + timer.label.replace(/'/g, "'\\''") + "'";
}
