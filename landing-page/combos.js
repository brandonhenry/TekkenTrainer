const fallbackData = {
    jin: {
        name: "Jin",
        style: "Tekken 8 Moveset",
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

const characterListEl = document.getElementById("character-list");
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
            const hitCount = getNumber(route.hits);
            const damage = getNumber(route.damage);

            return {
                title: buildComboTitle(comboType, index),
                type: comboType,
                starter: steps[0] || "Unknown starter",
                damage,
                carry: inferCarryFromHits(hitCount),
                notes: route.hits || "Practical route",
                steps
            };
        });

        transformed[characterId] = {
            name: formatCharacterName(characterId),
            style: "Tekken 8 Moveset",
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

function buildCharacterList() {
    const entries = Object.entries(comboData);
    characterListEl.innerHTML = entries.map(([id, character]) => `
        <button
            class="character-item ${id === state.characterId ? "is-active" : ""}"
            role="tab"
            aria-selected="${id === state.characterId}"
            data-character-id="${id}">
            <span class="avatar">${initialsFromName(character.name)}</span>
            <span class="character-meta">
                <strong>${character.name}</strong>
                <span>${character.style}</span>
            </span>
        </button>
    `).join("");
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
        ...combo.steps
    ].join(" ").toLowerCase();

    return tagMatch && searchable.includes(searchNeedle);
}

function createComboCard(combo) {
    const steps = combo.steps.map(step => `<li>${step}</li>`).join("");
    return `
        <article class="combo-card">
            <div class="combo-title-row">
                <h3>${combo.title}</h3>
                <span class="badge" data-type="${combo.type}">${combo.type}</span>
            </div>
            <p class="combo-starter">Starter: <strong>${combo.starter}</strong></p>
            <ol class="combo-steps">${steps}</ol>
            <div class="combo-footer">
                <div class="combo-stats">
                    <span>Damage<strong>${combo.damage}</strong></span>
                    <span>Carry<strong>${combo.carry}</strong></span>
                </div>
                <p class="combo-note">${combo.notes}</p>
            </div>
        </article>
    `;
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
    emptyStateEl.hidden = combos.length !== 0;
}

function attachEvents() {
    characterListEl.addEventListener("click", event => {
        const button = event.target.closest("[data-character-id]");
        if (!button) {
            return;
        }

        state.characterId = button.dataset.characterId;
        buildCharacterList();
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

    buildCharacterList();
    renderCombos();
    attachEvents();
}

init();
