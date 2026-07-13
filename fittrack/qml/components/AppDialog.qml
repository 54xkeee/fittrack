import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Dialog {
    id: root

    property string primaryText: qsTr("保存")
    property string secondaryText: qsTr("取消")
    property string primaryVariant: "primary"
    property string errorText: ""
    property bool primaryVisible: true
    property bool secondaryVisible: true
    property bool primaryEnabled: true
    property bool autoAccept: true
    property bool preferSecondaryFocus: false
    property Item initialFocusItem: null
    readonly property Item accessibleItem: dialogSurface
    readonly property Item primaryActionItem: primaryButton
    readonly property Item secondaryActionItem: secondaryButton
    readonly property real safeAvailableWidth: Overlay.overlay
                                                ? Overlay.overlay.width
                                                  - SafeArea.margins.left
                                                  - SafeArea.margins.right
                                                  - Design.Theme.space16 * 2
                                                : 400
    readonly property real safeAvailableHeight: Overlay.overlay
                                                 ? Overlay.overlay.height
                                                   - SafeArea.margins.top
                                                   - SafeArea.margins.bottom
                                                   - Design.Theme.space16 * 2
                                                 : 720
    readonly property bool stackButtons: Design.Theme.fontScale >= 1.3 || width < 360
    readonly property int visibleButtonCount: (primaryVisible ? 1 : 0)
                                              + (secondaryVisible ? 1 : 0)
    readonly property int buttonRows: visibleButtonCount > 0
                                      ? (stackButtons && visibleButtonCount > 1 ? 2 : 1)
                                      : 0
    readonly property real preferredContentHeight: {
        if (!contentItem)
            return 0
        let preferredHeight = contentItem.implicitHeight
        const children = contentItem.children
        for (let index = 0; index < children.length; ++index) {
            if (children[index].visible)
                preferredHeight = Math.max(preferredHeight, children[index].implicitHeight)
        }
        return preferredHeight
    }

    signal primaryRequested()

    function showError(message) {
        const fallback = qsTr("操作失败，请重试。")
        errorText = String(message || "").length > 0 ? String(message) : fallback
        Qt.callLater(function() {
            errorLabel.Accessible.announce(root.errorText, Accessible.Assertive)
        })
    }

    parent: Overlay.overlay
    width: Math.min(400, safeAvailableWidth)
    height: Math.min(safeAvailableHeight,
                     header.implicitHeight + preferredContentHeight + footer.implicitHeight
                     + topPadding + bottomPadding)
    x: Overlay.overlay
       ? SafeArea.margins.left
         + Math.max(Design.Theme.space16,
                    (Overlay.overlay.width - SafeArea.margins.left - SafeArea.margins.right
                     - width) / 2)
       : 0
    y: Overlay.overlay
       ? SafeArea.margins.top
         + Math.max(Design.Theme.space16,
                    (Overlay.overlay.height - SafeArea.margins.top - SafeArea.margins.bottom
                     - height) / 2)
       : 0
    modal: true
    focus: true
    padding: Design.Theme.space24
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: Design.Theme.scrim }

    background: Rectangle {
        id: dialogSurface
        color: Design.Theme.surface
        radius: Design.Theme.radiusLarge
        border.width: 1
        border.color: Design.Theme.outline
        Accessible.role: Accessible.Dialog
        Accessible.name: root.title
        Accessible.description: root.errorText
    }

    header: Label {
        text: root.title
        color: Design.Theme.surfaceText
        font.pixelSize: Design.Theme.typeTitle
        font.weight: Font.DemiBold
        leftPadding: Design.Theme.space24
        rightPadding: Design.Theme.space24
        topPadding: Design.Theme.space24
        wrapMode: Text.WordWrap
        // The dialog surface already exposes the title. Hiding this duplicate
        // heading prevents TalkBack from announcing the same title twice.
        Accessible.ignored: true
    }

    footer: Item {
        visible: root.primaryVisible || root.secondaryVisible
        implicitHeight: visible
                        ? root.buttonRows * Design.Theme.controlHeight
                          + Math.max(0, root.buttonRows - 1) * Design.Theme.space8
                          + Design.Theme.space24
                          + (errorLabel.visible ? errorLabel.implicitHeight + Design.Theme.space8 : 0)
                        : 0

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Design.Theme.space24
            anchors.rightMargin: Design.Theme.space24
            anchors.bottomMargin: Design.Theme.space24
            spacing: Design.Theme.space8

            Label {
                id: errorLabel
                visible: root.errorText.length > 0
                Layout.fillWidth: true
                text: root.errorText
                color: Design.Theme.error
                font.pixelSize: Design.Theme.typeLabel
                wrapMode: Text.WordWrap
                Accessible.name: text
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.stackButtons ? 1 : 2
                columnSpacing: Design.Theme.space8
                rowSpacing: Design.Theme.space8

                AppButton {
                    id: secondaryButton
                    visible: root.secondaryVisible
                    Layout.fillWidth: true
                    text: root.secondaryText
                    variant: "secondary"
                    Accessible.description: root.title
                    onClicked: root.reject()
                }

                AppButton {
                    id: primaryButton
                    visible: root.primaryVisible
                    enabled: root.primaryEnabled
                    Layout.fillWidth: true
                    text: root.primaryText
                    variant: root.primaryVariant
                    Accessible.description: root.title
                    onClicked: {
                        if (root.autoAccept)
                            root.accept()
                        else
                            root.primaryRequested()
                    }
                }
            }
        }
    }

    onOpened: {
        errorText = ""
        Qt.callLater(function() {
            if (root.initialFocusItem && root.initialFocusItem.visible
                    && root.initialFocusItem.enabled) {
                root.initialFocusItem.forceActiveFocus()
            } else if (root.preferSecondaryFocus
                       && secondaryButton.visible && secondaryButton.enabled) {
                secondaryButton.forceActiveFocus()
            } else if (primaryButton.visible && primaryButton.enabled) {
                primaryButton.forceActiveFocus()
            } else if (secondaryButton.visible && secondaryButton.enabled) {
                secondaryButton.forceActiveFocus()
            }
        })
    }
}
