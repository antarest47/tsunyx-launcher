// Calculator of the search boxes, the same file in Tsunyx Launcher and Tsunyx
// Search: + - * / with parentheses. Decimals with a point or a comma.
.pragma library

// The value of an expression and how many binary operators it has, or null
// if it isn't one.
function evaluate(text) {
    const source = text.replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, ".");
    let position = 0;
    let operators = 0;

    function peek() {
        return source[position];
    }

    function factor() {
        const c = peek();
        if (c === "+" || c === "-") {
            position++;
            const value = factor();
            return value === null ? null : (c === "-" ? -value : value);
        }
        if (c === "(") {
            position++;
            const value = sum();
            if (value === null || peek() !== ")") {
                return null;
            }
            position++;
            return value;
        }
        const match = /^(\d+\.?\d*|\.\d+)/.exec(source.slice(position));
        if (!match) {
            return null;
        }
        position += match[0].length;
        return parseFloat(match[0]);
    }

    function product() {
        let value = factor();
        while (value !== null && (peek() === "*" || peek() === "/")) {
            const c = source[position++];
            operators++;
            const right = factor();
            if (right === null) {
                return null;
            }
            value = c === "*" ? value * right : value / right;
        }
        return value;
    }

    function sum() {
        let value = product();
        while (value !== null && (peek() === "+" || peek() === "-")) {
            const c = source[position++];
            operators++;
            const right = product();
            if (right === null) {
                return null;
            }
            value = c === "+" ? value + right : value - right;
        }
        return value;
    }

    const value = sum();
    if (value === null || position !== source.length || Number.isNaN(value)) {
        return null;
    }
    return { value: value, operators: operators };
}

function format(value, withComma) {
    if (!Number.isFinite(value)) {
        return value < 0 ? "-∞" : "∞";
    }
    // Twelve digits are enough to hide errors like 0.1+0.2=0.30000000000000004.
    const text = String(parseFloat(value.toPrecision(12)));
    return withComma ? text.replace(".", ",") : text;
}

// What the box should say after pressing Enter ("2+2" gives "2+2=4"), or null
// if this isn't a calculation. Starting with / or * asks for one explicitly;
// otherwise it gives way when a result's name starts with what was typed
// (hasNameMatch). What follows the last "=" can go on: "2+2=4*3" gives
// "2+2=4*3=12".
function answer(text, hasNameMatch) {
    const typed = text.trim();
    const forced = typed[0] === "/" || typed[0] === "*";
    const equals = typed.lastIndexOf("=");
    const expression = equals >= 0 ? typed.slice(equals + 1) : (forced ? typed.slice(1) : typed);
    if (expression === "" || (hasNameMatch && !forced)) {
        return null;
    }
    const result = evaluate(expression);
    if (result === null || (result.operators === 0 && !(forced && equals < 0))) {
        return null;
    }
    return typed + "=" + format(result.value, expression.indexOf(",") >= 0);
}
