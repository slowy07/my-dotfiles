pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: root
    clip: true
    // This view has no session or authentication authority; the settings app uses it too.
    property var settings: ({})
    property var styleTokens: null
    property bool preview: false
    property bool interactive: true
    property real entrance: 1
    property real departure: 0
    property bool unlocking: false
    property bool layoutEditing: false
    property real editingUiScale: 1
    property string movingWidget: ""
    property var pendingPositions: ({})
    property point dragOffset: Qt.point(0, 0)
    property size movingSize: Qt.size(0, 0)
    readonly property real backgroundReveal: 1 - Math.pow(1 - Math.max(0, Math.min(1, entrance)), 3)
    readonly property real chromeOpacity: backgroundReveal * (1 - departure)
    property string userName: "User"
    property string homePath: ""
    property string wallpaperPath: ""
    property string textFont: "Sans Serif"
    property string timeFont: textFont
    property date now: new Date()
    property bool busy: false
    property bool retryBlocked: false
    property string authMessage: ""
    property bool authError: false
    property string prompt: "Password"
    property bool responseVisible: false
    property string trackTitle: ""
    property string trackArtist: ""
    property string albumArt: ""
    property bool playing: false
    property bool canPlay: false
    property bool canPrevious: false
    property bool canNext: false
    property bool canFavorite: false
    property bool favorite: false
    property string favoriteHint: "Favorite · available for connected Spotify"
    property real progress: 0
    property string elapsed: "0:00"
    property string duration: "0:00"
    property bool weatherReady: false
    property bool weatherStale: false
    property string temperature: "--"
    property string weatherCondition: "Weather unavailable"
    property string weatherLocation: "Local weather"
    property string weatherRange: ""
    property string weatherType: "sunny"
    property string feelsLike: "--"
    property string humidity: "--"
    property bool hasBattery: false
    property int batteryPercent: 0
    property bool charging: false
    // The shell and settings preview both supply the project's existing tokens.
    // Matching fallbacks keep the view usable on its own for visual review.
    readonly property color accent: styleValue("accent", "#0a84ff")
    readonly property color secondary: styleValue("textSecondary", "#b6b6bf")
    readonly property color foreground: styleValue("textPrimary", "#f5f5f7")
    readonly property color muted: styleValue("textMuted", "#acadb6")
    readonly property color surface: styleValue("panel", "#202125")
    readonly property color surfaceHigh: styleValue("module", "#303136")
    readonly property color errorColor: styleValue("error", "#ff7c72")
    readonly property bool dashboard: width / Math.max(1, height) > 1.2 && (option("showMusic", true) || option("showWeather", true))
    readonly property real cardAlpha: option("cardOpacity", 82) / 100
    readonly property real corner: option("radius", styleValue("radiusPanel", 28))
    readonly property string displayName: option("displayName", "").trim() || userName
    readonly property real sceneScale: Math.min(1, (width - 48) / body.width, (height - 140) / Math.max(1, body.height))
    readonly property real profileHeight: option("showAvatar", true) || option("showName", true) || option("showBattery", true) ? 88 : 0
    readonly property real clockHeight: option("showClock", true) ? 280 : option("showDate", true) ? 88 : 0
    readonly property real passwordHeight: 64
    // Reserve space for authentication feedback outside the editable input surface.
    readonly property real leftHeight: stackHeight([clockHeight, profileHeight, passwordHeight]) + 32
    readonly property real weatherHeight: option("showWeather", true) ? 176 : 0
    readonly property real musicHeight: option("showMusic", true) ? musicCard.height : 0
    readonly property real rightHeight: stackHeight([weatherHeight, musicHeight])
    readonly property real rightX: dashboard ? 496 : 0
    readonly property real rightY: dashboard ? 0 : leftHeight + (rightHeight > 0 ? 12 : 0)
    readonly property real rightWidth: dashboard ? 336 : 480

    signal submitted(string response)
    signal cancelAuthentication
    signal previousRequested
    signal playPauseRequested
    signal nextRequested
    signal favoriteRequested
    signal positionEdited(string widgetKey, real x, real y)

    function option(key, fallback) {
        return settings[key] === undefined ? fallback : settings[key];
    }
    function styleValue(key, fallback) {
        return styleTokens ? styleTokens[key] : fallback;
    }
    function stackHeight(heights) {
        const visibleHeights = heights.filter(height => height > 0);
        return visibleHeights.reduce((total, height) => total + height, 0) + Math.max(0, visibleHeights.length - 1) * 12;
    }
    function boundedCenter(value, extent, cardExtent) {
        const margin = Math.min(24, extent * 0.03);
        return Math.max(margin + cardExtent / 2, Math.min(extent - margin - cardExtent / 2, value));
    }
    function positionFor(key, defaultX, defaultY, cardWidth, cardHeight) {
        const positions = option("positions", {});
        const point = pendingPositions[key] || positions[key];
        if (!(option("customLayoutEnabled", false) || layoutEditing) || !point || !isFinite(point.x) || !isFinite(point.y))
            return Qt.point(defaultX, defaultY);
        const factor = body.scale;
        const centerX = boundedCenter(point.x * width, width, cardWidth * factor);
        const centerY = boundedCenter(point.y * height, height, cardHeight * factor);
        return Qt.point((centerX - body.x) / factor - cardWidth / 2, (centerY - body.y) / factor - cardHeight / 2);
    }
    function widgetPosition(key) {
        const cards = {profile: profileCard, clock: clockCard, password: passwordCard, weather: weatherCard, music: musicCard};
        const card = cards[key];
        if (!card)
            return Qt.point(0.5, 0.5);
        return Qt.point((body.x + (card.x + card.width / 2) * body.scale) / Math.max(1, width),
                        (body.y + (card.y + card.height / 2) * body.scale) / Math.max(1, height));
    }
    function beginMove(key, card, pointer) {
        if (!layoutEditing || unlocking)
            return;
        const origin = card.parent.mapToItem(root, card.x, card.y);
        movingWidget = key;
        movingSize = Qt.size(card.width, card.height);
        dragOffset = Qt.point(pointer.x - origin.x, pointer.y - origin.y);
    }
    function moveWidget(pointer) {
        if (movingWidget === "" || !layoutEditing)
            return;
        const cardWidth = movingSize.width * body.scale;
        const cardHeight = movingSize.height * body.scale;
        const centerX = boundedCenter(pointer.x - dragOffset.x + cardWidth / 2, width, cardWidth);
        const centerY = boundedCenter(pointer.y - dragOffset.y + cardHeight / 2, height, cardHeight);
        const next = Object.assign({}, pendingPositions);
        next[movingWidget] = {
            x: centerX / width,
            y: centerY / height
        };
        pendingPositions = next;
    }
    function finishMove() {
        const point = pendingPositions[movingWidget];
        if (movingWidget !== "" && point)
            positionEdited(movingWidget, point.x, point.y);
        movingWidget = "";
        pendingPositions = ({});
    }
    function cancelMove() {
        movingWidget = "";
        pendingPositions = ({});
    }
    onLayoutEditingChanged: if (!layoutEditing)
        cancelMove()
    function imageUrl(path) {
        if (!path)
            return "";
        if (path.startsWith("~/"))
            path = homePath + path.substring(1);
        return path.startsWith("/") ? "file://" + path.split("/").map(encodeURIComponent).join("/") : path;
    }
    function clearInput() {
        password.clear();
    }
    function formattedTime() {
        const hours = option("use24Hour", true) ? now.getHours() : (now.getHours() % 12 || 12);
        return ("0" + hours).slice(-2) + ":" + ("0" + now.getMinutes()).slice(-2) + (option("showSeconds", false) ? ":" + ("0" + now.getSeconds()).slice(-2) : "");
    }
    function clockHours() {
        return ("0" + (option("use24Hour", true) ? now.getHours() : now.getHours() % 12 || 12)).slice(-2);
    }
    function focusInput() {
        if (interactive && !unlocking)
            password.forceActiveFocus();
    }
    function submit() {
        if (!interactive || preview || unlocking || busy || retryBlocked || password.text.length === 0)
            return;
        const response = password.text;
        password.clear();
        submitted(response);
    }
    onBusyChanged: if (!busy)
        focusInput()
    onInteractiveChanged: if (interactive)
        focusInput()
    Component.onCompleted: if (!preview)
        focusInput()

    Item {
        id: backdrop
        anchors.fill: parent
        scale: 1.04 - 0.04 * root.backgroundReveal + 0.025 * root.departure
        opacity: 0.12 + 0.88 * root.backgroundReveal

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#1c222b"
                }
                GradientStop {
                    position: 0.52
                    color: "#454c58"
                }
                GradientStop {
                    position: 1
                    color: "#202125"
                }
            }
        }
        Image {
            id: backgroundImage
            objectName: "lockWallpaper"
            anchors.fill: parent
            source: root.imageUrl(root.option("wallpaperPath", "") || root.wallpaperPath)
            sourceSize.width: Math.min(2560, root.width * 1.5)
            sourceSize.height: Math.min(1600, root.height * 1.5)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: !backgroundEffect.visible
        }
        MultiEffect {
            id: backgroundEffect
            anchors.fill: parent
            source: backgroundImage
            visible: backgroundImage.status === Image.Ready
            opacity: visible ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
            blurEnabled: root.option("blur", 48) > 0
            blur: Math.min(1, root.option("blur", 48) / 100 + (1 - root.backgroundReveal) * 0.2) * (1 - root.departure)
            blurMax: 64
            autoPaddingEnabled: false
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.03, 0.035, root.option("dim", 32) / 100 * (1 - root.departure))
        }
        Rectangle {
            anchors.fill: parent
            opacity: 1 - root.departure
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#05000000"
                }
                GradientStop {
                    position: 1
                    color: "#55080a0e"
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 24
        visible: root.layoutEditing
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.3)
        radius: 12
    }
    Rectangle {
        visible: root.layoutEditing
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        width: 1
        height: parent.height - 48
        color: Qt.alpha(root.accent, 0.18)
    }
    Rectangle {
        visible: root.layoutEditing
        anchors.verticalCenter: parent.verticalCenter
        x: 24
        width: parent.width - 48
        height: 1
        color: Qt.alpha(root.accent, 0.18)
    }

    Item {
        id: body
        width: root.dashboard ? 832 : 480
        height: root.dashboard ? Math.max(root.leftHeight, root.rightHeight) : root.leftHeight + (root.rightHeight > 0 ? 12 + root.rightHeight : 0)
        x: (root.width - width * scale) / 2
        y: (root.height - height * scale) / 2
        scale: Math.max(0.1, root.sceneScale)
        transformOrigin: Item.TopLeft

        LockCard {
            id: profileCard
            styleTokens: root.styleTokens
            objectName: "profileCard"
            z: root.movingWidget === "profile" ? 10 : 0
            readonly property point layoutPosition: root.positionFor("profile", 0, root.clockHeight > 0 ? root.clockHeight + 12 : 0, width, height)
            x: layoutPosition.x
            y: layoutPosition.y
            LockLayoutHandle {
                editor: root
                widgetKey: "profile"
                label: "User information"
            }
            entrance: root.entrance
            departure: root.departure
            stagger: 0.06
            width: 480
            height: 88
            visible: root.profileHeight > 0
            radius: root.corner
            surfaceColor: root.surface
            surfaceOpacity: root.cardAlpha

            Rectangle {
                id: avatarFrame
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                height: 56
                radius: 28
                color: root.surfaceHigh
                visible: root.option("showAvatar", true)
                Image {
                    id: avatar
                    anchors.fill: parent
                    source: root.option("showAvatar", true) ? root.imageUrl(root.option("avatarPath", "")) : ""
                    sourceSize: Qt.size(112, 112)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: avatarMask
                    }
                }
                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: 28
                    visible: false
                    layer.enabled: true
                }
                LockGlyph {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    name: "user"
                    ink: root.foreground
                    visible: avatar.status !== Image.Ready
                }
            }
            Text {
                x: root.option("showAvatar", true) ? 90 : 28
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, (profileBattery.visible ? profileBattery.x : profileLock.x) - x - 20)
                visible: root.option("showName", true)
                text: root.displayName
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.foreground
                font.family: root.textFont
                font.pixelSize: 22
                font.weight: Font.Medium
            }
            LockGlyph {
                id: profileLock
                anchors.right: parent.right
                anchors.rightMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                visible: !profileBattery.visible
                width: 20
                height: 20
                name: root.unlocking ? "check" : "lock"
                ink: root.muted
            }
            Row {
                id: profileBattery
                objectName: "profileBattery"
                anchors.right: parent.right
                anchors.rightMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: root.option("showBattery", true)
                LockGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    name: root.charging ? "bolt" : "battery"
                    ink: root.foreground
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hasBattery ? root.batteryPercent + "%" : "AC"
                    color: root.foreground
                    font.family: root.textFont
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    Accessible.name: root.hasBattery ? (root.charging ? "Charging, " : "Battery, ") + root.batteryPercent + " percent" : "Connected to power"
                }
            }
        }

        LockCard {
            id: clockCard
            styleTokens: root.styleTokens
            objectName: "clockCard"
            z: root.movingWidget === "clock" ? 10 : 0
            readonly property point layoutPosition: root.positionFor("clock", 0, 0, width, height)
            x: layoutPosition.x
            y: layoutPosition.y
            LockLayoutHandle {
                editor: root
                widgetKey: "clock"
                label: "Time and date"
            }
            entrance: root.entrance
            departure: root.departure
            width: 480
            height: root.clockHeight
            visible: root.clockHeight > 0
            radius: root.corner
            surfaceColor: root.surface
            surfaceOpacity: root.cardAlpha

            Column {
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 10
                Row {
                    objectName: "clockText"
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.option("showClock", true)
                    spacing: 12
                    Accessible.name: root.formattedTime()
                    Text {
                        text: root.clockHours()
                        color: root.foreground
                        font.family: root.timeFont
                        font.pixelSize: 152
                        font.weight: Font.DemiBold
                        font.letterSpacing: -7
                        font.features: {
                            "tnum": 1
                        }
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 182
                    }
                    Text {
                        text: ("0" + root.now.getMinutes()).slice(-2)
                        color: Qt.alpha(root.foreground, 0.84)
                        font.family: root.timeFont
                        font.pixelSize: 152
                        font.weight: Font.DemiBold
                        font.letterSpacing: -7
                        font.features: {
                            "tnum": 1
                        }
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 182
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    visible: root.option("showDate", true) || root.option("showSeconds", false) || !root.option("use24Hour", true)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.option("showDate", true)
                        text: Qt.formatDate(root.now, "dddd, d MMMM")
                        color: root.foreground
                        font.family: root.textFont
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }
                    Rectangle {
                        visible: root.option("showSeconds", false) || !root.option("use24Hour", true)
                        width: timeDetail.implicitWidth + 20
                        height: 30
                        radius: 15
                        color: root.surfaceHigh
                        Text {
                            id: timeDetail
                            anchors.centerIn: parent
                            text: (root.option("showSeconds", false) ? ("0" + root.now.getSeconds()).slice(-2) + "s" : "") + (!root.option("use24Hour", true) ? (root.option("showSeconds", false) ? " · " : "") + Qt.formatTime(root.now, "AP") : "")
                            color: root.secondary
                            font.family: root.textFont
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        LockCard {
            id: passwordCard
            styleTokens: root.styleTokens
            objectName: "passwordCard"
            z: root.movingWidget === "password" ? 10 : 1
            readonly property point layoutPosition: root.positionFor("password", 0, root.clockHeight + root.profileHeight + (root.clockHeight > 0 ? 12 : 0) + (root.profileHeight > 0 ? 12 : 0), width, height)
            x: layoutPosition.x
            y: layoutPosition.y
            LockLayoutHandle {
                editor: root
                widgetKey: "password"
                label: "Password"
            }
            entrance: root.entrance
            departure: root.departure
            stagger: 0.12
            width: 480
            height: root.passwordHeight
            radius: Math.min(root.corner, height / 2)
            surfaceColor: root.surface
            surfaceOpacity: root.cardAlpha
            border.width: password.activeFocus || root.authError ? 1.5 : 1
            border.color: root.authError ? root.errorColor : password.activeFocus ? Qt.alpha(root.accent, 0.8) : outlineColor

            LockGlyph {
                x: 22
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                ink: root.secondary
            }
            TextField {
                id: password
                objectName: "passwordInput"
                x: 58
                width: parent.width - 126
                height: parent.height
                enabled: root.interactive && !root.unlocking && !root.busy && !root.retryBlocked && !root.preview
                background: null
                echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                passwordCharacter: "●"
                passwordMaskDelay: 0
                placeholderText: root.preview ? "Enter your password" : root.prompt
                placeholderTextColor: root.muted
                color: root.foreground
                font.family: root.textFont
                font.pixelSize: 16
                selectionColor: Qt.alpha(root.accent, 0.35)
                maximumLength: 1024
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                selectByMouse: false
                onAccepted: root.submit()
                Keys.onEscapePressed: {
                    clear();
                    root.cancelAuthentication();
                }
            }
            LockAction {
                styleTokens: root.styleTokens
                x: parent.width - 52
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                prominent: true
                glyph: root.unlocking ? "check" : "arrow"
                text: "Unlock"
                enabled: root.interactive && !root.unlocking && !root.preview && !root.busy && !root.retryBlocked && password.text.length > 0
                onClicked: root.submit()
            }
            Text {
                objectName: "passwordFeedback"
                // Keep feedback visible when the input is dragged to the bottom edge.
                y: body.y + (passwordCard.y + passwordCard.height + 11 + height) * body.scale <= root.height - 12 ? passwordCard.height + 11 : -height - 11
                width: parent.width
                text: root.unlocking ? "Unlocked" : root.busy ? "Verifying…" : root.authMessage
                textFormat: Text.PlainText
                color: root.authError ? root.errorColor : root.secondary
                font.family: root.textFont
                font.pixelSize: 12
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }
        }

        LockCard {
            id: weatherCard
            styleTokens: root.styleTokens
            objectName: "weatherCard"
            z: root.movingWidget === "weather" ? 10 : 0
            readonly property point layoutPosition: root.positionFor("weather", root.rightX, root.rightY, width, height)
            x: layoutPosition.x
            y: layoutPosition.y
            LockLayoutHandle {
                editor: root
                widgetKey: "weather"
                label: "Weather"
            }
            entrance: root.entrance
            departure: root.departure
            stagger: 0.1
            width: root.rightWidth
            height: 176
            visible: root.option("showWeather", true)
            radius: root.corner
            surfaceColor: root.surface
            surfaceOpacity: root.cardAlpha
            Text {
                x: 24
                y: 20
                width: parent.width - 48
                text: root.weatherLocation + (root.weatherStale ? " · cached" : "")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.muted
                font.family: root.textFont
                font.pixelSize: 12
            }
            Text {
                x: 22
                y: 43
                text: root.temperature
                color: root.foreground
                font.family: root.textFont
                font.pixelSize: 52
                font.weight: Font.Medium
                font.letterSpacing: -2
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 24
                y: 49
                width: 56
                height: 56
                radius: 20
                color: "transparent"
                LockGlyph {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    name: root.weatherType === "sunny" ? "sun" : root.weatherType === "rain" || root.weatherType === "thunder" ? "rain" : root.weatherType === "snow" ? "snow" : "cloud"
                    ink: root.foreground
                }
            }
            Text {
                x: 24
                y: 107
                width: parent.width - 48
                text: root.weatherCondition
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.secondary
                font.family: root.textFont
                font.pixelSize: 14
            }
            Text {
                x: 24
                y: 140
                width: parent.width - 48
                text: root.weatherReady ? "Feels like " + root.feelsLike + "   ·   " + root.humidity + " humidity" : "No weather data"
                elide: Text.ElideRight
                color: root.muted
                font.family: root.textFont
                font.pixelSize: 11
            }
        }

        LockCard {
            id: musicCard
            styleTokens: root.styleTokens
            objectName: "musicCard"
            z: root.movingWidget === "music" ? 10 : 0
            readonly property point layoutPosition: root.positionFor("music", root.rightX, root.rightY + (root.weatherHeight > 0 ? root.weatherHeight + 12 : 0), width, height)
            x: layoutPosition.x
            y: layoutPosition.y
            LockLayoutHandle {
                editor: root
                widgetKey: "music"
                label: "Music player"
            }
            entrance: root.entrance
            departure: root.departure
            stagger: 0.18
            readonly property bool showDetails: root.option("showTrackInfo", true) || root.option("showAlbumArt", true)
            readonly property int progressY: showDetails ? 116 : 24
            width: root.rightWidth
            height: showDetails ? 236 : 144
            visible: root.option("showMusic", true)
            radius: root.corner
            surfaceColor: root.surface
            surfaceOpacity: root.cardAlpha
            Rectangle {
                x: root.option("showTrackInfo", true) ? 24 : (parent.width - width) / 2
                y: 24
                width: 64
                height: 64
                radius: 10
                color: root.surfaceHigh
                visible: root.option("showAlbumArt", true)
                Image {
                    id: cover
                    anchors.fill: parent
                    source: musicCard.visible && root.option("showAlbumArt", true) ? root.albumArt : ""
                    asynchronous: true
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: coverMask
                    }
                }
                Rectangle {
                    id: coverMask
                    anchors.fill: parent
                    radius: 10
                    visible: false
                    layer.enabled: true
                }
                LockGlyph {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    name: "music"
                    ink: root.foreground
                    visible: cover.status !== Image.Ready
                }
            }
            Column {
                objectName: "trackInfo"
                visible: root.option("showTrackInfo", true)
                x: root.option("showAlbumArt", true) ? 102 : 24
                y: 32
                width: parent.width - x - 24
                spacing: 7
                Text {
                    width: parent.width
                    text: root.trackTitle || "Nothing playing"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.foreground
                    font.family: root.textFont
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: root.trackArtist || "No active player"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.muted
                    font.family: root.textFont
                    font.pixelSize: 13
                }
            }
            Rectangle {
                x: 62
                y: musicCard.progressY + 5
                width: parent.width - 124
                height: 6
                radius: 3
                color: root.surfaceHigh
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.progress))
                    height: parent.height
                    radius: 3
                    color: root.foreground
                }
            }
            Text {
                x: 24
                y: musicCard.progressY
                text: root.elapsed
                color: root.muted
                font.family: root.textFont
                font.pixelSize: 10
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 24
                y: musicCard.progressY
                text: root.duration
                color: root.muted
                font.family: root.textFont
                font.pixelSize: 10
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: musicCard.progressY + 40
                spacing: 24
                LockAction {
                    styleTokens: root.styleTokens
                    glyph: "previous"
                    transport: true
                    text: "Previous track"
                    enabled: root.canPrevious && (root.interactive || root.preview)
                    onClicked: root.previousRequested()
                }
                LockAction {
                    styleTokens: root.styleTokens
                    glyph: root.playing ? "pause" : "play"
                    text: root.playing ? "Pause" : "Play"
                    transport: true
                    enabled: root.canPlay && (root.interactive || root.preview)
                    onClicked: root.playPauseRequested()
                }
                LockAction {
                    styleTokens: root.styleTokens
                    glyph: "next"
                    transport: true
                    text: "Next track"
                    enabled: root.canNext && (root.interactive || root.preview)
                    onClicked: root.nextRequested()
                }
                LockAction {
                    styleTokens: root.styleTokens
                    glyph: "heart"
                    transport: true
                    text: root.favoriteHint
                    selected: root.favorite
                    enabled: root.canFavorite && (root.interactive || root.preview)
                    onClicked: root.favoriteRequested()
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        width: parent.width - 64
        opacity: root.chromeOpacity
        text: root.option("message", "")
        visible: text.length > 0
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: root.secondary
        font.family: root.textFont
        font.pixelSize: 12
    }
}
