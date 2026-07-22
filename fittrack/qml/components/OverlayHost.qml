import QtQuick

Item {
    id: root

    property var activeOverlay: null

    function present(component, properties) {
        dismiss()
        const overlay = component.createObject(root, properties || {})
        if (!overlay)
            return null
        activeOverlay = overlay
        overlay.closed.connect(function() {
            if (root.activeOverlay !== overlay)
                return
            root.activeOverlay = null
            overlay.destroy()
        })
        overlay.open()
        return overlay
    }

    function dismiss() {
        if (activeOverlay)
            activeOverlay.close()
    }
}
