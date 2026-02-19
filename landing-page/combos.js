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
    filter: "all",
    view: "grid",
    activeComboIndex: 0
};
const ICON_PNG_BASE = "./assets/inputs_png";
const ICON_SVG_BASE = "./assets/inputs_svg";
const CHARACTER_IMG_BASE = "./assets/characters";
const STORAGE_KEY = "tekkentrainer:lastCharacter";
const VIEW_STORAGE_KEY = "tekkentrainer:combosView";

const characterStripEl = document.getElementById("character-strip");
const comboGridEl = document.getElementById("combo-grid");
const emptyStateEl = document.getElementById("empty-state");
const selectedNameEl = document.getElementById("selected-name");
const selectedStyleEl = document.getElementById("selected-style");
const selectedDifficultyEl = document.getElementById("selected-difficulty");
const searchInputEl = document.getElementById("combo-search");
const filterButtons = document.querySelectorAll(".tag-btn");
const viewButtons = document.querySelectorAll(".view-btn");
const deckPrevBtn = document.getElementById("deck-prev");
const deckNextBtn = document.getElementById("deck-next");
const deckCounterEl = document.getElementById("deck-counter");
const shareBtn = document.getElementById("share-combo");
const tierButtons = document.querySelectorAll(".tier-btn");
const moveViewButtons = document.querySelectorAll(".move-view-btn");
const moveTableBody = document.getElementById("move-table-body");
const moveFullscreenBtn = document.getElementById("move-fullscreen");
const moveTablePanel = document.querySelector(".move-table-panel");
let comboData = fallbackData;
let lastRenderedCombos = [];
let isDragging = false;
let dragStartX = 0;
let dragDeltaX = 0;
let activePointerId = null;
let pendingComboIndex = null;
let activeMoveTier = "all";
let moveListView = "buttons";
let isMoveTableFullscreen = false;

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
    const storedCharacter = localStorage.getItem(STORAGE_KEY);
    const storedView = localStorage.getItem(VIEW_STORAGE_KEY);
    state.characterId = storedCharacter && transformed[storedCharacter] ? storedCharacter : keys[0];
    state.view = storedView === "deck" || storedView === "grid" ? storedView : state.view;
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

function scrollToActiveCharacter() {
    const activeButton = characterStripEl.querySelector(".charbox.is-active");
    if (activeButton) {
        activeButton.scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" });
    }
}

function syncViewButtons() {
    viewButtons.forEach(button => {
        const isActive = button.dataset.view === state.view;
        button.classList.toggle("is-active", isActive);
        button.setAttribute("aria-selected", String(isActive));
    });
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
        if (moveTableBody) {
            moveTableBody.innerHTML = "";
        }
        return;
    }

    const combos = activeCharacter.combos.filter(comboMatchesFilter);
    lastRenderedCombos = combos;

    selectedNameEl.textContent = activeCharacter.name;
    selectedStyleEl.textContent = activeCharacter.style;
    selectedDifficultyEl.textContent = activeCharacter.difficulty;

    if (state.activeComboIndex >= combos.length) {
        state.activeComboIndex = Math.max(0, combos.length - 1);
    }

    comboGridEl.innerHTML = combos.map(createComboCard).join("");
    wireImageFallbacks(comboGridEl);
    emptyStateEl.hidden = combos.length !== 0;
    if (typeof pendingComboIndex === "number") {
        state.activeComboIndex = Math.max(0, Math.min(combos.length - 1, pendingComboIndex));
        pendingComboIndex = null;
    }
    applyDeckState();
    updateDeckUI();
    renderMoveTable(activeCharacter.combos);
}

function tierFromLength(length) {
    if (length <= 1) return "single";
    if (length <= 3) return "simple";
    if (length <= 5) return "medium-simple";
    if (length <= 7) return "medium";
    if (length <= 9) return "advanced";
    return "expert";
}

function labelForTier(tier) {
    switch (tier) {
        case "single":
            return "Single";
        case "simple":
            return "Simple";
        case "medium-simple":
            return "Med-Simple";
        case "medium":
            return "Medium";
        case "advanced":
            return "Advanced";
        case "expert":
            return "Expert";
        default:
            return "All";
    }
}

function renderMoveTable(combos) {
    if (!moveTableBody) return;
    const comboRows = (combos || []).map(combo => {
        const steps = combo.steps || [];
        const tier = tierFromLength(steps.length);
        return {
            tier,
            tierLabel: labelForTier(tier),
            moves: steps,
            routeMoves: combo.routeMoves || [],
            type: combo.type || "bnb",
            notes: combo.notes || ""
        };
    });

    const singleRows = [];
    if (activeMoveTier === "single") {
        const seen = new Set();
        comboRows.forEach(row => {
            if (Array.isArray(row.routeMoves) && row.routeMoves.length) {
                row.routeMoves.forEach(move => {
                    const key = `${move.type}:${move.img || move.name}`;
                    if (seen.has(key)) return;
                    seen.add(key);
                    singleRows.push({
                        tier: "single",
                        tierLabel: "Single",
                        moves: [move.name],
                        routeMoves: [move],
                        type: "single",
                        notes: "Individual input"
                    });
                });
                return;
            }
            row.moves.forEach(move => {
                const key = `text:${move}`;
                if (seen.has(key)) return;
                seen.add(key);
                singleRows.push({
                    tier: "single",
                    tierLabel: "Single",
                    moves: [move],
                    routeMoves: [{ type: "text", name: move, img: null }],
                    type: "single",
                    notes: "Individual input"
                });
            });
        });
    }

    const rows = activeMoveTier === "single" ? singleRows : comboRows;
    const filtered = activeMoveTier === "all"
        ? rows
        : rows.filter(row => row.tier === activeMoveTier);

    if (!filtered.length) {
        moveTableBody.innerHTML = `
            <tr class="move-row">
                <td class="move-note" colspan="4">No move strings match this tier.</td>
            </tr>
        `;
        return;
    }

    moveTableBody.innerHTML = filtered.map(row => `
        <tr class="move-row">
            <td class="move-tier">${escapeHtml(row.tierLabel)}</td>
            <td>
                ${moveListView === "text"
                    ? `<div class="move-string">${row.moves.map(move => `<span>${escapeHtml(move)}</span>`).join("")}</div>`
                    : `<div class="combo-route move-string">${createRouteMarkup(row.routeMoves)}</div>`
                }
            </td>
            <td><span class="badge" data-type="${escapeHtml(row.type)}">${escapeHtml(row.type)}</span></td>
            <td class="move-note">${escapeHtml(row.notes)}</td>
        </tr>
    `).join("");
}

function setMoveTableFullscreen(nextState) {
    if (!moveTablePanel) return;
    isMoveTableFullscreen = nextState;
    moveTablePanel.classList.toggle("is-fullscreen", isMoveTableFullscreen);
    document.body.classList.toggle("move-table-fullscreen", isMoveTableFullscreen);
    if (moveFullscreenBtn) {
        moveFullscreenBtn.setAttribute("aria-label", isMoveTableFullscreen ? "Exit full screen move strings" : "Full screen move strings");
        moveFullscreenBtn.innerHTML = isMoveTableFullscreen ? "<span aria-hidden=\"true\">✕</span>" : "<span aria-hidden=\"true\">⛶</span>";
    }
}

function applyDeckState() {
    const cards = Array.from(comboGridEl.querySelectorAll(".combo-card"));
    if (state.view !== "deck") {
        comboGridEl.classList.remove("is-deck", "is-dragging");
        comboGridEl.style.removeProperty("--drag-x");
        cards.forEach(card => {
            card.classList.remove("is-active", "is-prev", "is-next", "is-hidden");
        });
        return;
    }

    comboGridEl.classList.add("is-deck");
    cards.forEach((card, index) => {
        card.classList.remove("is-active", "is-prev", "is-next", "is-hidden");
        if (index === state.activeComboIndex) {
            card.classList.add("is-active");
        } else if (index === state.activeComboIndex - 1) {
            card.classList.add("is-prev");
        } else if (index === state.activeComboIndex + 1) {
            card.classList.add("is-next");
        } else {
            card.classList.add("is-hidden");
        }
    });
}

function updateDeckUI() {
    const total = lastRenderedCombos.length;
    const current = total ? state.activeComboIndex + 1 : 0;
    deckCounterEl.textContent = `${current} / ${total}`;
    const isDeck = state.view === "deck";

    deckPrevBtn.disabled = !isDeck || state.activeComboIndex <= 0;
    deckNextBtn.disabled = !isDeck || state.activeComboIndex >= total - 1;
    deckPrevBtn.closest(".deck-controls")?.classList.toggle("is-hidden", !isDeck);
    if (shareBtn) {
        shareBtn.disabled = total === 0;
    }
}

function setView(view) {
    if (state.view === view) {
        return;
    }
    state.view = view;
    localStorage.setItem(VIEW_STORAGE_KEY, view);
    viewButtons.forEach(button => {
        const isActive = button.dataset.view === view;
        button.classList.toggle("is-active", isActive);
        button.setAttribute("aria-selected", String(isActive));
    });
    applyDeckState();
    updateDeckUI();
}

function goToCombo(index) {
    const total = lastRenderedCombos.length;
    if (!total) {
        return;
    }
    const clamped = Math.max(0, Math.min(total - 1, index));
    state.activeComboIndex = clamped;
    applyDeckState();
    updateDeckUI();
}

function goToNextCombo() {
    goToCombo(state.activeComboIndex + 1);
}

function goToPrevCombo() {
    goToCombo(state.activeComboIndex - 1);
}

function handlePointerDown(event) {
    if (state.view !== "deck" || isDragging || lastRenderedCombos.length <= 1) {
        return;
    }
    if (event.pointerType === "mouse" && event.button !== 0) {
        return;
    }
    isDragging = true;
    activePointerId = event.pointerId;
    dragStartX = event.clientX;
    dragDeltaX = 0;
    comboGridEl.classList.add("is-dragging");
    comboGridEl.style.setProperty("--drag-x", "0px");
    comboGridEl.setPointerCapture(event.pointerId);
}

function handlePointerMove(event) {
    if (!isDragging || activePointerId !== event.pointerId) {
        return;
    }
    dragDeltaX = event.clientX - dragStartX;
    comboGridEl.style.setProperty("--drag-x", `${dragDeltaX}px`);
}

function endDrag(event) {
    if (!isDragging || activePointerId !== event.pointerId) {
        return;
    }
    comboGridEl.releasePointerCapture(event.pointerId);
    comboGridEl.classList.remove("is-dragging");
    const threshold = 80;
    if (Math.abs(dragDeltaX) > threshold) {
        if (dragDeltaX < 0) {
            goToNextCombo();
        } else {
            goToPrevCombo();
        }
    }
    comboGridEl.style.setProperty("--drag-x", "0px");
    isDragging = false;
    activePointerId = null;
    dragDeltaX = 0;
}

function attachEvents() {
    characterStripEl.addEventListener("click", event => {
        const button = event.target.closest("[data-character-id]");
        if (!button) {
            return;
        }

        state.characterId = button.dataset.characterId;
        state.activeComboIndex = 0;
        localStorage.setItem(STORAGE_KEY, state.characterId);
        buildCharacterStrip();
        scrollToActiveCharacter();
        renderCombos();
    });

    searchInputEl.addEventListener("input", event => {
        state.search = event.target.value;
        state.activeComboIndex = 0;
        renderCombos();
    });

    filterButtons.forEach(button => {
        button.addEventListener("click", () => {
            const { filter } = button.dataset;
            state.filter = filter;
            state.activeComboIndex = 0;

            filterButtons.forEach(item => {
                item.classList.toggle("is-active", item.dataset.filter === filter);
            });

            renderCombos();
        });
    });

    tierButtons.forEach(button => {
        button.addEventListener("click", () => {
            const { tier } = button.dataset;
            activeMoveTier = tier || "all";
            tierButtons.forEach(item => {
                item.classList.toggle("is-active", item.dataset.tier === activeMoveTier);
                item.setAttribute("aria-selected", String(item.dataset.tier === activeMoveTier));
            });
            const activeCharacter = comboData[state.characterId];
            if (activeCharacter) {
                renderMoveTable(activeCharacter.combos);
            }
        });
    });

    moveViewButtons.forEach(button => {
        button.addEventListener("click", () => {
            moveListView = button.dataset.view === "text" ? "text" : "buttons";
            moveViewButtons.forEach(item => {
                const isActive = item.dataset.view === moveListView;
                item.classList.toggle("is-active", isActive);
                item.setAttribute("aria-selected", String(isActive));
            });
            const activeCharacter = comboData[state.characterId];
            if (activeCharacter) {
                renderMoveTable(activeCharacter.combos);
            }
        });
    });

    moveFullscreenBtn?.addEventListener("click", () => {
        setMoveTableFullscreen(!isMoveTableFullscreen);
    });

    viewButtons.forEach(button => {
        button.addEventListener("click", () => {
            setView(button.dataset.view);
        });
    });

    deckPrevBtn.addEventListener("click", () => {
        if (state.view === "deck") {
            goToPrevCombo();
        }
    });

    deckNextBtn.addEventListener("click", () => {
        if (state.view === "deck") {
            goToNextCombo();
        }
    });

    shareBtn?.addEventListener("click", async () => {
        const total = lastRenderedCombos.length;
        if (!total) {
            return;
        }
        const comboIndex = Math.max(0, Math.min(total - 1, state.activeComboIndex));
        const params = new URLSearchParams();
        params.set("character", state.characterId);
        params.set("combo", String(comboIndex + 1));
        params.set("view", "deck");
        const shareUrl = `${window.location.origin}${window.location.pathname}?${params.toString()}`;
        const shareData = {
            title: "TEKKEN Trainer Combo",
            text: `Check out this combo for ${selectedNameEl.textContent}`,
            url: shareUrl
        };

        if (navigator.share) {
            try {
                await navigator.share(shareData);
                return;
            } catch (error) {
                console.warn("Share cancelled or failed.", error);
            }
        }

        if (navigator.clipboard?.writeText) {
            await navigator.clipboard.writeText(shareUrl);
            shareBtn.textContent = "Link copied";
            setTimeout(() => {
                shareBtn.textContent = "Share combo";
            }, 1400);
        } else {
            window.prompt("Copy this link:", shareUrl);
        }
    });

    comboGridEl.addEventListener("pointerdown", handlePointerDown);
    comboGridEl.addEventListener("pointermove", handlePointerMove);
    comboGridEl.addEventListener("pointerup", endDrag);
    comboGridEl.addEventListener("pointercancel", endDrag);

    window.addEventListener("keydown", event => {
        if (state.view !== "deck") {
            return;
        }
        if (event.key === "ArrowRight") {
            goToNextCombo();
        }
        if (event.key === "ArrowLeft") {
            goToPrevCombo();
        }
    });
}

function init() {
    try {
        loadCombosFromAsset();
    } catch (error) {
        console.warn("Using fallback combo data.", error);
    }

    const urlParams = new URLSearchParams(window.location.search);
    const sharedCharacter = urlParams.get("character");
    const sharedCombo = Number(urlParams.get("combo"));
    const sharedView = urlParams.get("view");

    if (sharedCharacter && comboData[sharedCharacter]) {
        state.characterId = sharedCharacter;
    }
    if (sharedView === "deck") {
        state.view = "deck";
    }
    if (Number.isFinite(sharedCombo) && sharedCombo > 0) {
        pendingComboIndex = sharedCombo - 1;
    }

    buildCharacterStrip();
    syncViewButtons();
    scrollToActiveCharacter();
    renderCombos();
    attachEvents();
}

init();
