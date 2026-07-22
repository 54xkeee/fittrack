import QtQuick

Item {
    id: root

    property var pendingAction: null

    function show(message, options) {
        const config = options || ({})
        pendingAction = typeof config.action === "function" ? config.action : null
        snackbar.message = String(message || "")
        snackbar.actionText = String(config.actionText || "")
        snackbar.duration = config.duration === undefined ? 4000 : Number(config.duration)
        snackbar.open()
    }

    function dismiss() {
        snackbar.close()
        pendingAction = null
    }

    AppSnackbar {
        id: snackbar
        onActionTriggered: {
            const callback = root.pendingAction
            root.dismiss()
            if (callback)
                callback()
        }
    }
}
