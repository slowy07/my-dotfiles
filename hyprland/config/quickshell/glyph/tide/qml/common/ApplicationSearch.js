.pragma library

function normalize(value) {
    let normalized = String(value || "").toLocaleLowerCase();
    if (normalized.normalize)
        normalized = normalized.normalize("NFKD").replace(/[\u0300-\u036f]/g, "");
    return normalized.replace(/[_./\\:;,+()[\]{}-]+/g, " ")
        .replace(/\s+/g, " ")
        .trim();
}

function queryTokens(query) {
    const normalized = normalize(query);
    return normalized === "" ? [] : normalized.split(" ");
}

function isBoundary(text, index) {
    return index === 0 || text.charAt(index - 1) === " ";
}

function textMatchScore(token, text) {
    if (token === "" || text === "")
        return -1;

    if (text === token)
        return 2000;
    if (text.indexOf(token) === 0)
        return 1650 - Math.min(120, text.length - token.length);

    let position = text.indexOf(token, 1);
    let boundaryPosition = -1;
    while (position >= 0) {
        if (isBoundary(text, position)) {
            boundaryPosition = position;
            break;
        }
        position = text.indexOf(token, position + 1);
    }
    if (boundaryPosition >= 0)
        return 1450 - Math.min(160, boundaryPosition * 3);

    const substringPosition = text.indexOf(token);
    if (substringPosition >= 0)
        return 1180 - Math.min(240, substringPosition * 4);

    // Ordered fuzzy match. Consecutive characters and word initials receive
    // bonuses, while long gaps and a late first match are penalized.
    let searchFrom = 0;
    let previousPosition = -1;
    let score = 620;
    for (let index = 0; index < token.length; ++index) {
        const matchPosition = text.indexOf(token.charAt(index), searchFrom);
        if (matchPosition < 0)
            return -1;

        if (index === 0)
            score -= Math.min(180, matchPosition * 6);
        if (isBoundary(text, matchPosition))
            score += 55;
        if (previousPosition >= 0) {
            const gap = matchPosition - previousPosition - 1;
            if (gap === 0)
                score += 42;
            else
                score -= Math.min(120, gap * 8);
        }

        previousPosition = matchPosition;
        searchFrom = matchPosition + 1;
    }

    score -= Math.min(100, text.length - token.length);
    return Math.max(1, score);
}

function applicationFields(entry) {
    return [
        { text: normalize(entry.name), weight: 620 },
        { text: normalize(entry.genericName), weight: 300 },
        { text: normalize(entry.keywords ? entry.keywords.join(" ") : ""), weight: 260 },
        { text: normalize(entry.id), weight: 180 },
        { text: normalize(entry.startupClass), weight: 160 },
        { text: normalize(entry.comment), weight: 100 },
        { text: normalize(entry.categories ? entry.categories.join(" ") : ""), weight: 80 }
    ];
}

function applicationScore(entry, query) {
    if (!entry)
        return -1;

    const tokens = queryTokens(query);
    if (tokens.length === 0)
        return 0;

    const fields = applicationFields(entry);
    let total = 0;
    for (let tokenIndex = 0; tokenIndex < tokens.length; ++tokenIndex) {
        let bestTokenScore = -1;
        for (let fieldIndex = 0; fieldIndex < fields.length; ++fieldIndex) {
            const matchScore = textMatchScore(tokens[tokenIndex], fields[fieldIndex].text);
            if (matchScore >= 0)
                bestTokenScore = Math.max(bestTokenScore, matchScore + fields[fieldIndex].weight);
        }
        if (bestTokenScore < 0)
            return -1;
        total += bestTokenScore;
    }

    // Prefer an uninterrupted whole-query match when token scores tie.
    const wholeQueryScore = textMatchScore(normalize(query), fields[0].text);
    if (wholeQueryScore >= 0)
        total += Math.round(wholeQueryScore * 0.35);
    return total;
}
