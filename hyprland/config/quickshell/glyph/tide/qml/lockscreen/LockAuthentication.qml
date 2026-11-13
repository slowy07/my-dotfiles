import QtQuick

Item {
    id: root
    // Inject the PAM conversation so the state machine can be tested without
    // ever authenticating or locking the developer's session.
    required property var pam
    property int successResult: 0
    property bool sessionLocked: false
    property bool attempting: false
    property string pendingResponse: ""
    property bool hasPendingResponse: false
    property string message: ""
    property bool failed: false
    readonly property bool busy: attempting && !pam.responseRequired
    readonly property bool retryBlocked: retryTimer.running
    readonly property string prompt: attempting && pam.responseRequired && pam.message ? pam.message : "Password"
    readonly property bool responseVisible: attempting && pam.responseRequired && pam.responseVisible
    signal authenticated()
    signal clearInputs()

    function clearPending() {
        pendingResponse = "";
        hasPendingResponse = false;
        clearInputs();
    }

    function submit(response) {
        if (!sessionLocked || retryBlocked || busy || response.length === 0) return;
        failed = false;
        message = "";
        if (attempting && pam.responseRequired) {
            pam.respond(response);
            clearInputs();
            return;
        }
        pendingResponse = response;
        hasPendingResponse = true;
        attempting = true;
        timeout.restart();
        if (!pam.start()) {
            attempting = false;
            timeout.stop();
            clearPending();
            failed = true;
            message = "Could not start system authentication. Try again.";
        }
    }

    function cancel() {
        attempting = false;
        timeout.stop();
        clearPending();
        if (pam.active) pam.abort();
        message = "";
        failed = false;
    }
    onSessionLockedChanged: {
        cancel();
        retryTimer.stop();
    }

    Connections {
        target: root.pam
        function onPamMessage() {
            if (!root.attempting || !root.sessionLocked) return;
            if (root.pam.responseRequired && root.hasPendingResponse) {
                const response = root.pendingResponse;
                root.clearPending();
                root.pam.respond(response);
            } else if (root.pam.message) {
                root.message = root.pam.message;
                root.failed = root.pam.messageIsError;
            }
        }
        function onCompleted(result) {
            const mayUnlock = root.attempting && root.sessionLocked;
            root.attempting = false;
            timeout.stop();
            root.clearPending();
            if (!mayUnlock) return;
            if (result === root.successResult) {
                root.message = "";
                root.failed = false;
                root.authenticated();
            } else {
                root.failed = true;
                root.message = "Authentication failed. Please try again.";
                retryTimer.restart();
            }
        }
    }
    Timer { id: retryTimer; interval: 1500 }
    Timer {
        id: timeout
        objectName: "authenticationTimeout"
        interval: 120000
        onTriggered: {
            root.cancel();
            root.failed = true;
            root.message = "Authentication timed out. Try again.";
        }
    }
    Component.onDestruction: { pendingResponse = ""; if (pam.active) pam.abort(); }
}
