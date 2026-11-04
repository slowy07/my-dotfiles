pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settings

// glyph: чёрный, белые точки, один красный. Палитра, шрифты, движение, состояние (тема, тишина) и вид hypr/kitty — здесь
Singleton {
    id: root

    // состояние переживает перезапуск, его же читает лок (отдельный процесс)
    readonly property alias state: st
    readonly property bool light: st.light

    // colorschemes (prefs · LOOK): four-tone stack for the shell and 16 ANSI for kitty
    readonly property var schemes: ({
        everblush: {
            bg: "#141b1e", s1: "#232a2d", s2: "#232a2d", s3: "#b3b9b8",
            mute: "#4a4a4a", grey: "#b3b9b8", fg: "#dadada", ink: "#141b1e", red: "#e57474",
            ansi: ["#232a2d", "#e57474", "#8ccf7e", "#e5c76b", "#67b0e8", "#c47fd5", "#6cbfbf", "#dadada",
                   "#b3b9b8", "#e57474", "#8ccf7e", "#e5c76b", "#67b0e8", "#c47fd5", "#6cbfbf", "#dadada"]
        },
        aphelion: {
            bg: "#101319", s1: "#171b24", s2: "#171b24", s3: "#3A435A",
            mute: "#3A435A", grey: "#f4f3ee", fg: "#f4f3ee", ink: "#101319", red: "#E34F4F",
            ansi: ["#171b24", "#E34F4F", "#69bfce", "#e37e4f", "#5679E3", "#956dca", "#5599E2", "#f4f3ee",
                   "#3A435A", "#DE2B2B", "#56B7C8", "#DE642B", "#3E66E0", "#885AC4", "#3F8CDE", "#DDDBCF"]
        }
    })
    readonly property var scheme: schemes[st.scheme] ?? schemes.everblush
    readonly property var schemeNames: Object.keys(schemes)

    // светлая тема — та же раскладка, серые наоборот; схема красит тёмную, красный — из неё
    readonly property color bg: light ? "#E9E9E9" : scheme.bg   // фон, обои
    readonly property color s1: light ? "#FFFFFF" : scheme.s1   // бар, панели
    readonly property color s2: light ? "#F1F1F1" : scheme.s2   // плитки, выкл.
    readonly property color s3: light ? "#D9D9D9" : scheme.s3   // линии, погасшие точки
    readonly property color mute: light ? "#B8B8B8" : scheme.mute // неактивное
    readonly property color grey: light ? "#6E6E6E" : scheme.grey // метки, вторичное
    readonly property color fg: light ? "#0B0B0B" : scheme.fg   // текст, вкл., фокус
    readonly property color ink: light ? "#FFFFFF" : scheme.ink  // текст на белой плитке
    readonly property color red: scheme.red                     // максимум одна вещь на экране, и только «живое»
    readonly property color glow: light ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 0.6)
    readonly property color scrim: light ? Qt.rgba(0.91, 0.91, 0.91, 0.8) : Qt.rgba(0, 0, 0, 0.74)

    readonly property string dot: "Doto"                   // цифры и короткие слова, не мельче 26px
    readonly property string ui: "Space Grotesk"
    readonly property string mono: "JetBrainsMono Nerd Font"            // метки капсом
    readonly property string nf: "JetBrainsMono Nerd Font" // иконки

    // холст макета 1920×1080 → экран. ponytail: по первому экрану; мониторы разного размера — считать от screen окна
    readonly property real s: {
        const sc = Quickshell.screens[0];
        return sc ? Math.min(sc.width / 1920, sc.height / 1080) : 1;
    }

    // glide: ease-out-quart, без перелёта — как bezier glide в hypr
    readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]
    readonly property int t: 350

    // обои рисуются из копии под экран (её делает пикер, magick): оригинал бывает png на 40 МБ, грузился бы секунды.
    // ponytail: копии нет (кэш стёрли, путь вписан руками) — пусто, сетка и шар, пока не открыть пикер
    readonly property string wallCache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/glyph/walls"
    function wallSrc(p) { return p ? `${wallCache}/${p.slice(p.lastIndexOf("/") + 1)}.jpg` : ""; }

    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    // часы по настройке 12/24: «09» или «9»
    function hh(d) { const h = d.getHours(); return st.clock24 ? String(h).padStart(2, "0") : String(h % 12 || 12); }
    function hex(c) { return c.toString().slice(1, 7).toUpperCase(); }

    // как в Rules: apply() на старте должен видеть glyph.json, а не умолчания
    Component.onCompleted: stateFile.waitForJob()

    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice/glyph.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        // запись — раз в конце хода: writeAdapter() на каждое поле подряд путает соседние
        onAdapterUpdated: Qt.callLater(stateFile.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: st
            property bool light: false
            property bool dnd: false  // новые не показываются, критические — всегда
            property int unread: 0    // для лока
            // ---- то, что крутят настройки (prefs) ----
            property var widgets: ["weather", "calendar", "cpu", "player", "buds", "system"] // бенто дома по порядку, см. kinds
            property bool clock24: true
            property bool blink: true      // двоеточие часов мигает
            property string name: ""       // в приветствии; пусто — $USER
            property bool grid: true       // сетка точек на обоях
            property bool orb: true        // полутоновый шар
            property string scheme: "everblush" // prefs · LOOK: everblush | aphelion
            // обои (пикер wall/Walls, рисует components/Wall): путь к картинке; пусто — сетка и шар. Папку пикера можно сменить здесь
            property string wall: ""
            property string wallDir: ""    // пусто — ~/Pictures/Wallpapers
            property int wallLook: 0       // 0 точки, 1 серое фото, 2 цвет
            property int wallPitch: 10     // шаг точек, px
            property int wallBright: 85    // %, от фона до картинки
            property int rounding: 20      // окна hypr
            property bool edges: true      // Glyph-полосы по краям (громкость/яркость, вспышки, прогресс)
            property int briSteps: 20      // яркость с клавиш: делений на шкалу, 40/20/10 — шаг 2.5/5/10 %
            property bool quickHover: true // быстрые настройки по наведению на правый край
            property bool deckHover: true  // deck — панель снизу по центру, вылезает по наведению на край
            property var deck: ["clock", "weather", "perf", "net", "media"] // её секции по порядку, см. decks
            property var bar: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"] // трей бара сверху вниз, см. bars
            property bool barTitle: true   // заголовок окна столбиком в баре
            // запись (quick/Rec, Sys.recArgs)
            property int recArea: 0        // 0 весь монитор, 1 область (slurp)
            property int recAudio: 0       // 0 без звука, 1 система, 2 микрофон, 3 оба одной дорожкой
            property int recFps: 60
            property int recQuality: 2     // medium, high, very_high, ultra
            property bool recCursor: true
        }
    }

    // виджеты бенто: id → ширина в ячейках (сетка 3 колонки × 3 ряда по 220). Не влезло — не показывается
    readonly property var kinds: ({ weather: 1, calendar: 1, cpu: 1, ram: 1, gpu: 1, disk: 1, battery: 1, buds: 1, player: 2, system: 3, cat: 1, cava: 1 })
    // секции deck
    readonly property var decks: ["clock", "weather", "perf", "net", "media"]
    // трей бара
    readonly property var bars: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"]

    // ---- вид всего, что вне шелла. Зовёт только shell.qml: на старте и при смене темы ----
    // hypr наследует demonshot: монитор, ввод, простой, ночник и движение ставит его же Rules (shell.qml), анимации — из
    // конфига hypr. Отсюда — зазоры/рамка/blur/тени из его rules.json, а свои у glyph — цвета рамок, тени, групп, фон и
    // скругление 20 (без них остались бы красные свечение и группы demonshot из hypr/variables.lua).
    // Обратно к demonshot: `rice switch` делает hyprctl reload, его applyAll перекрасит
    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    // kitty подключает этот файл после своих цветов (include в kitty.conf); demonshot пишет туда же свою палитру
    FileView { id: kitty; path: Quickshell.env("HOME") + "/.config/demonshot/kitty.conf"; printErrors: false }
    // 16 ANSI выбранной схемы: пастель только терминалу. В светлой теме 0↔15 и 7↔8, чтобы белое не терялось на белом
    readonly property var ansi: scheme.ansi

    function apply() {
        // игровой режим (Rules.store.game) — поверх настроек, как ultra: рамка 1, без зазоров и скругления, tearing для
        // окон с immediate (игры, hyprland/rules.lua). Вышли — свои значения вернутся, allow_tearing — false, как в general.lua
        const r = Rules.store, g = r.game;
        const c = x => `"rgb(${hex(x)})"`;
        // тень: в тёмной — еле заметное белое свечение, в светлой — мягкая чёрная
        const shadow = light ? "rgba(0000002E)" : `rgba(${hex(fg)}1A)`;
        hypr(`hl.config({ general = { gaps_in = ${g ? 0 : r.gapsIn}, gaps_out = ${g ? 0 : r.gapsOut}, border_size = ${g ? 1 : r.border}, allow_tearing = ${g}, `
           + `col = { active_border = ${c(fg)}, inactive_border = ${c(s3)} } }, `
           + `decoration = { rounding = ${g ? 0 : st.rounding}, blur = { enabled = ${Rules.blurOn} }, shadow = { enabled = ${Rules.shadowOn}, color = "${shadow}" } }, `
           + `group = { col = { border_active = ${c(fg)}, border_inactive = ${c(s3)}, border_locked_active = ${c(fg)}, border_locked_inactive = ${c(mute)} }, `
           + `groupbar = { font_family = "${mono}", text_color = ${c(fg)}, col = { active = ${c(s3)}, inactive = ${c(s1)}, locked_active = ${c(s3)}, locked_inactive = ${c(s1)} } } }, `
           + `misc = { background_color = ${c(bg)} } })`);

        // only the scheme itself: font, tabs, animations, selection and keys stay in ~/.config/kitty/kitty.conf
        const a = light ? [15, 1, 2, 3, 4, 5, 6, 8, 7, 9, 10, 11, 12, 13, 14, 0].map(i => ansi[i]) : ansi;
        kitty.setText("# glyph: colorscheme only — Theme.apply() writes, do not edit by hand\n" + [
            ["foreground", fg], ["background", bg], ["cursor", fg]
        ].concat(a.map((c, i) => ["color" + i, c])).map(([k, v]) => `${k} ${typeof v === "string" ? v : v.toString().slice(0, 7).toUpperCase()}`).join("\n") + "\n");
        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
    }
}
