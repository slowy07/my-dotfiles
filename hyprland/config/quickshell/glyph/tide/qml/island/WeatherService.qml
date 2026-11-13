pragma ComponentBehavior: Bound

import QtQuick
import IslandBackend

Item {
    id: root

    readonly property var userConfig: UserConfig

    property bool weatherEnabled: userConfig ? userConfig.weatherEnabled : true
    property string location: userConfig ? userConfig.weatherLocation : ""
    property string units: userConfig ? userConfig.weatherUnits : "metric"
    property int refreshInterval: userConfig ? userConfig.weatherRefreshInterval : 1800000

    property real temp: 0
    property real feelsLike: 0
    property int humidity: 0
    property real windSpeed: 0
    property string windDir: ""
    property int uvIndex: 0
    property string condition: ""
    property string weatherCode: ""
    property string weatherType: "sunny"
    property string iconGlyph: "\ue30d"
    property string iconColor: "#f4c542"
    property string cityName: ""
    property string countryName: ""
    property string displayLocation: ""
    property string sunrise: ""
    property string sunset: ""
    property real minTemp: 0
    property real maxTemp: 0
    property var forecast: []
    property bool loading: false
    property string errorMessage: ""
    property var lastUpdated: null
    property bool hasData: false
    property bool isStale: false
    property bool isError: errorMessage.length > 0 && !isStale

    readonly property string tempString: hasData ? (Math.round(temp) + "°" + (units === "imperial" ? "F" : "C")) : "--"
    readonly property string feelsLikeString: hasData ? (Math.round(feelsLike) + "°" + (units === "imperial" ? "F" : "C")) : "--"
    readonly property string windSpeedString: hasData ? (Math.round(windSpeed) + (units === "imperial" ? " mph" : " km/h")) : "--"
    readonly property string rangeString: hasData ? (Math.round(maxTemp) + "° / " + Math.round(minTemp) + "°") : ""

    function parseWeatherCode(code) {
        const c = parseInt(code, 10);
        if (c === 113) {
            return { type: "sunny", glyph: "\ue30d", color: "#f4c542" };
        }
        if (c === 116) {
            return { type: "partly_cloudy", glyph: "\ue302", color: "#f4c542" };
        }
        if (c === 119 || c === 122) {
            return { type: "cloudy", glyph: "\ue312", color: "#9aa0a6" };
        }
        if ([143, 248, 260].indexOf(c) !== -1) {
            return { type: "fog", glyph: "\ue313", color: "#8a8e99" };
        }
        if ([200, 386, 389, 392, 395].indexOf(c) !== -1) {
            return { type: "thunder", glyph: "\ue31d", color: "#e8b84a" };
        }
        if ([179, 182, 185, 227, 230, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].indexOf(c) !== -1) {
            return { type: "snow", glyph: "\ue31a", color: "#d8e8f4" };
        }
        if ([176, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 317, 320, 353, 356, 359].indexOf(c) !== -1) {
            return { type: "rain", glyph: "\ue318", color: "#4a9de8" };
        }
        return { type: "cloudy", glyph: "\ue312", color: "#9aa0a6" };
    }

    function refresh() {
        if (!weatherEnabled)
            return;

        loading = true;
        const loc = (location || "").trim();
        const url = "https://wttr.in/" + (loc.length > 0 ? encodeURIComponent(loc) : "") + "?format=j1";

        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;

            root.loading = false;
            if (xhr.status !== 200) {
                root.errorMessage = "Weather fetch failed (" + xhr.status + ")";
                root.isStale = root.hasData;
                return;
            }

            try {
                const data = JSON.parse(xhr.responseText);
                if (!data || !data.current_condition || data.current_condition.length === 0) {
                    root.errorMessage = "Invalid weather data";
                    root.isStale = root.hasData;
                    return;
                }

                const current = data.current_condition[0];
                const today = data.weather && data.weather.length > 0 ? data.weather[0] : null;
                const isMetric = root.units === "metric";

                root.temp = isMetric ? parseFloat(current.temp_C) : parseFloat(current.temp_F);
                root.feelsLike = isMetric ? parseFloat(current.FeelsLikeC) : parseFloat(current.FeelsLikeF);
                root.humidity = parseInt(current.humidity, 10) || 0;
                root.windSpeed = isMetric ? parseFloat(current.windspeedKmph) : parseFloat(current.windspeedMiles);
                root.windDir = current.winddir16Point || "";
                root.uvIndex = parseInt(current.uvIndex, 10) || 0;
                root.condition = (current.weatherDesc && current.weatherDesc[0]) ? current.weatherDesc[0].value : "";
                root.weatherCode = current.weatherCode || "";

                const iconData = root.parseWeatherCode(current.weatherCode);
                root.weatherType = iconData.type;
                root.iconGlyph = iconData.glyph;
                root.iconColor = iconData.color;

                if (today && today.astronomy && today.astronomy[0]) {
                    root.sunrise = today.astronomy[0].sunrise || "";
                    root.sunset = today.astronomy[0].sunset || "";
                }

                if (today) {
                    root.maxTemp = isMetric ? parseFloat(today.maxtempC) : parseFloat(today.maxtempF);
                    root.minTemp = isMetric ? parseFloat(today.mintempC) : parseFloat(today.mintempF);
                }

                let city = "";
                let country = "";
                if (data.nearest_area && data.nearest_area[0]) {
                    const area = data.nearest_area[0];
                    if (area.areaName && area.areaName[0])
                        city = area.areaName[0].value || "";
                    if (area.country && area.country[0])
                        country = area.country[0].value || "";
                }
                root.cityName = city;
                root.countryName = country;
                root.displayLocation = loc.length > 0 ? loc : (city.length > 0 ? (country.length > 0 ? city + ", " + country : city) : "Local Weather");

                if (data.weather && data.weather.length > 0) {
                    const parsedForecast = [];
                    const count = Math.min(3, data.weather.length);
                    for (let i = 0; i < count; i++) {
                        const day = data.weather[i];
                        const middayHourly = (day.hourly && day.hourly.length > 4) ? day.hourly[4] : (day.hourly ? day.hourly[0] : null);
                        const middayCode = middayHourly ? middayHourly.weatherCode : "116";
                        const middayDesc = (middayHourly && middayHourly.weatherDesc && middayHourly.weatherDesc[0]) ? middayHourly.weatherDesc[0].value : "";
                        const dayIcon = root.parseWeatherCode(middayCode);

                        let dayLabel = "";
                        if (i === 0) {
                            dayLabel = "Today";
                        } else if (i === 1) {
                            dayLabel = "Tomorrow";
                        } else {
                            try {
                                const d = new Date(day.date);
                                const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                                dayLabel = days[d.getDay()] || day.date;
                            } catch (e) {
                                dayLabel = day.date;
                            }
                        }

                        parsedForecast.push({
                            date: day.date,
                            dayLabel: dayLabel,
                            maxTemp: isMetric ? parseFloat(day.maxtempC) : parseFloat(day.maxtempF),
                            minTemp: isMetric ? parseFloat(day.mintempC) : parseFloat(day.mintempF),
                            condition: middayDesc,
                            weatherType: dayIcon.type,
                            iconGlyph: dayIcon.glyph,
                            iconColor: dayIcon.color
                        });
                    }
                    root.forecast = parsedForecast;
                }

                root.lastUpdated = new Date();
                root.hasData = true;
                root.isStale = false;
                root.errorMessage = "";
            } catch (err) {
                root.errorMessage = "Weather parse error";
                root.isStale = root.hasData;
            }
        };

        xhr.open("GET", url);
        xhr.send();
    }

    Timer {
        id: refreshTimer
        interval: Math.max(60000, root.refreshInterval)
        running: root.weatherEnabled
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }

    onLocationChanged: root.refresh()
    onUnitsChanged: root.refresh()
    onWeatherEnabledChanged: {
        if (root.weatherEnabled && !root.hasData)
            root.refresh();
    }

    Component.onCompleted: {
        if (root.weatherEnabled)
            root.refresh();
    }
}
