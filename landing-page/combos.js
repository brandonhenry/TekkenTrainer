const fallbackData = {
    jin: {
        name: "Jin",
        style: "TEKKEN 8 Moveset",
        difficulty: "Execution: Variable",
        combos: [
            {
                title: "Sample BnB",
                type: "bnb",
                starter: "u/f+4",
                damage: 64,
                carry: "Mid",
                notes: "Fallback combo if JSON is unavailable.",
                steps: ["u/f+4", "f+3~3", "b+3", "f+4,2"]
            }
        ]
    }
};

const state = {
    characterId: "jin",
    search: "",
    filter: "all"
};
const ICON_PNG_BASE = "./assets/inputs_png";
const ICON_SVG_BASE = "./assets/inputs_svg";
const CHARACTER_IMG_BASE = "./assets/characters";

const characterStripEl = document.getElementById("character-strip");
const comboGridEl = document.getElementById("combo-grid");
const emptyStateEl = document.getElementById("empty-state");
const selectedNameEl = document.getElementById("selected-name");
const selectedStyleEl = document.getElementById("selected-style");
const selectedDifficultyEl = document.getElementById("selected-difficulty");
const searchInputEl = document.getElementById("combo-search");
const filterButtons = document.querySelectorAll(".tag-btn");
let comboData = fallbackData;

function formatCharacterName(rawName) {
    return rawName
        .replace(/[_-]+/g, " ")
        .replace(/\s+/g, " ")
        .trim()
        .split(" ")
        .map(part => part.charAt(0).toUpperCase() + part.slice(1))
        .join(" ");
}

function getNumber(value, fallback = 0) {
    const match = String(value || "").match(/\d+/);
    return match ? Number(match[0]) : fallback;
}

function inferType(comboText, moves) {
    const search = `${comboText || ""} ${moves.map(move => move?.name || "").join(" ")}`.toLowerCase();
    if (search.includes("heat")) {
        return "heat";
    }
    if (search.includes("wall")) {
        return "wall";
    }
    return "bnb";
}

function inferCarryFromHits(hitCount) {
    if (hitCount >= 9) {
        return "High";
    }
    if (hitCount >= 6) {
        return "Mid";
    }
    return "Low";
}

function parseTextSteps(text) {
    const parts = String(text || "")
        .split(/\u25ba|->|▶|>/)
        .map(step => step.trim())
        .filter(Boolean);

    return parts.length ? parts : [String(text || "Unknown route").trim()];
}

function escapeHtml(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#39;");
}

function isImageMove(move) {
    return move && move.type === "img" && typeof move.img === "string" && move.img.endsWith(".svg");
}

function toRouteMoves(route, steps) {
    if (Array.isArray(route?.moves) && route.moves.length > 0) {
        return route.moves.map(move => ({
            type: move?.type === "img" ? "img" : "text",
            name: String(move?.name || "Unknown"),
            img: typeof move?.img === "string" ? move.img : null
        }));
    }

    return steps.map(step => ({
        type: "text",
        name: String(step || "Unknown"),
        img: null
    }));
}

function starterFromRoute(routeMoves, steps) {
    if (routeMoves.length > 0) {
        return routeMoves[0].name || "Unknown starter";
    }
    return steps[0] || "Unknown starter";
}

function iconPathsFromMove(move) {
    if (!isImageMove(move)) {
        return null;
    }
    const stem = move.img.slice(0, -4);
    return {
        png: `${ICON_PNG_BASE}/${stem}.png`,
        svg: `${ICON_SVG_BASE}/${move.img}`
    };
}

function buildComboTitle(comboType, index) {
    const label = comboType === "heat" ? "Heat Route" : comboType === "wall" ? "Wall Carry" : "BnB Route";
    return `${label} ${index + 1}`;
}

function transformAssetData(rawData) {
    const transformed = {};
    const entries = Object.entries(rawData || {});

    entries.forEach(([characterId, routes]) => {
        if (!Array.isArray(routes) || routes.length === 0) {
            return;
        }

        const mappedCombos = routes.map((route, index) => {
            const comboType = inferType(route.text, route.moves || []);
            const steps = parseTextSteps(route.text);
            const routeMoves = toRouteMoves(route, steps);
            const hitCount = getNumber(route.hits);
            const damage = getNumber(route.damage);

            return {
                title: buildComboTitle(comboType, index),
                type: comboType,
                starter: starterFromRoute(routeMoves, steps),
                damage,
                carry: inferCarryFromHits(hitCount),
                notes: route.hits || "Practical route",
                steps,
                routeMoves
            };
        });

        transformed[characterId] = {
            name: formatCharacterName(characterId),
            style: "TEKKEN 8 Moveset",
            difficulty: `Execution: Variable (${mappedCombos.length} combos)`,
            combos: mappedCombos
        };
    });

    return transformed;
}

function loadCombosFromAsset() {
    const rawData = window.TEKKEN_COMBOS_DATA;
    if (!rawData || typeof rawData !== "object") {
        throw new Error("Global combo data was not found.");
    }

    const transformed = transformAssetData(rawData);
    const keys = Object.keys(transformed);

    if (!keys.length) {
        throw new Error("No combos found in combos.json");
    }

    comboData = transformed;
    state.characterId = keys[0];
}

function initialsFromName(name) {
    const words = name.split(" ");
    return words.slice(0, 2).map(word => word[0]).join("").toUpperCase();
}

function buildCharacterStrip() {
    const entries = Object.entries(comboData);
    characterStripEl.innerHTML = entries.map(([id, character]) => `
        <button
            class="charbox ${id === state.characterId ? "is-active" : ""}"
            role="tab"
            aria-selected="${id === state.characterId}"
            data-character-id="${id}">
            <img class="charbox-image" src="${escapeHtml(CHARACTER_IMG_BASE)}/${escapeHtml(id)}.jpg" alt="${escapeHtml(character.name)}">
            <span class="charbox-overlay"></span>
            <span class="charbox-name">${escapeHtml(character.name)}</span>
            <span class="charbox-initials">${escapeHtml(initialsFromName(character.name))}</span>
        </button>
    `).join("");
    wireCharacterImageFallbacks(characterStripEl);
}

function comboMatchesFilter(combo) {
    const tagMatch = state.filter === "all" ? true : combo.type === state.filter;
    const searchNeedle = state.search.trim().toLowerCase();

    if (!searchNeedle) {
        return tagMatch;
    }

    const searchable = [
        combo.title,
        combo.starter,
        combo.notes,
        combo.type,
        ...combo.steps,
        ...(combo.routeMoves || []).map(move => move.name)
    ].join(" ").toLowerCase();

    return tagMatch && searchable.includes(searchNeedle);
}

function createRouteMarkup(routeMoves) {
    if (!Array.isArray(routeMoves) || routeMoves.length === 0) {
        return `<span class="move-token is-text">No route data</span>`;
    }

    return routeMoves.map((move, index) => {
        const icon = iconPathsFromMove(move);
        const token = icon
            ? `<span class="move-token is-img" title="${escapeHtml(move.name)}">
                    <img class="move-icon" src="${escapeHtml(icon.png)}" data-fallback-src="${escapeHtml(icon.svg)}" alt="${escapeHtml(move.name)}">
               </span>`
            : `<span class="move-token is-text">${escapeHtml(move.name)}</span>`;

        if (index === 0) {
            return token;
        }
        return `<span class="route-separator">►</span>${token}`;
    }).join("");
}

function createComboCard(combo) {
    const routeMarkup = createRouteMarkup(combo.routeMoves || []);
    const notation = (combo.steps || []).map(step => escapeHtml(step)).join(" ► ");
    return `
        <article class="combo-card">
            <div class="combo-title-row">
                <h3>${escapeHtml(combo.title)}</h3>
                <span class="badge" data-type="${escapeHtml(combo.type)}">${escapeHtml(combo.type)}</span>
            </div>
            <p class="combo-starter">Starter: <strong>${escapeHtml(combo.starter)}</strong></p>
            <div class="combo-route">${routeMarkup}</div>
            <p class="combo-notation">${notation}</p>
            <div class="combo-footer">
                <div class="combo-stats">
                    <span>Damage<strong>${escapeHtml(combo.damage)}</strong></span>
                    <span>Carry<strong>${escapeHtml(combo.carry)}</strong></span>
                </div>
                <p class="combo-note">${escapeHtml(combo.notes)}</p>
            </div>
        </article>
    `;
}

function wireImageFallbacks(root) {
    root.querySelectorAll("img.move-icon[data-fallback-src]").forEach(image => {
        image.addEventListener("error", () => {
            const fallbackSrc = image.getAttribute("data-fallback-src");
            if (!fallbackSrc || image.dataset.failedFallback === "1") {
                const token = image.closest(".move-token");
                if (token) {
                    token.classList.remove("is-img");
                    token.classList.add("is-text");
                    token.textContent = image.alt || "input";
                }
                return;
            }

            if (image.src.endsWith(fallbackSrc)) {
                image.dataset.failedFallback = "1";
                image.dispatchEvent(new Event("error"));
                return;
            }
            image.src = fallbackSrc;
        });
    });
}

function wireCharacterImageFallbacks(root) {
    root.querySelectorAll("img.charbox-image").forEach(image => {
        image.addEventListener("error", () => {
            const box = image.closest(".charbox");
            if (!box) return;
            box.classList.add("is-missing-image");
        });
    });
}

function renderCombos() {
    const activeCharacter = comboData[state.characterId];
    if (!activeCharacter) {
        comboGridEl.innerHTML = "";
        emptyStateEl.hidden = false;
        emptyStateEl.textContent = "Unable to load combo data.";
        return;
    }

    const combos = activeCharacter.combos.filter(comboMatchesFilter);

    selectedNameEl.textContent = activeCharacter.name;
    selectedStyleEl.textContent = activeCharacter.style;
    selectedDifficultyEl.textContent = activeCharacter.difficulty;

    comboGridEl.innerHTML = combos.map(createComboCard).join("");
    wireImageFallbacks(comboGridEl);
    emptyStateEl.hidden = combos.length !== 0;
}

function attachEvents() {
    characterStripEl.addEventListener("click", event => {
        const button = event.target.closest("[data-character-id]");
        if (!button) {
            return;
        }

        state.characterId = button.dataset.characterId;
        buildCharacterStrip();
        renderCombos();
    });

    searchInputEl.addEventListener("input", event => {
        state.search = event.target.value;
        renderCombos();
    });

    filterButtons.forEach(button => {
        button.addEventListener("click", () => {
            const { filter } = button.dataset;
            state.filter = filter;

            filterButtons.forEach(item => {
                item.classList.toggle("is-active", item.dataset.filter === filter);
            });

            renderCombos();
        });
    });
}

function init() {
    try {
        loadCombosFromAsset();
    } catch (error) {
        console.warn("Using fallback combo data.", error);
    }

    buildCharacterStrip();
    renderCombos();
    attachEvents();
}

init();
