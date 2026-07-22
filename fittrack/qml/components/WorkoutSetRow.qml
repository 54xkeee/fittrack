import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Rectangle {
    id: root

    property string state: "pending"
    property int setNumber: 1
    property string previousText: "—"
    property string repsText: "—"
    property alias weightInputText: setWeight.text
    property alias repsInputText: setReps.text
    property string weightPlaceholder: "0"
    property string repsPlaceholder: "次数"
    property bool pureBodyweight: false
    property bool submitting: false
    property bool validationError: false

    readonly property bool active: state === "active"
    readonly property bool completed: state === "completed"
    readonly property bool inputValid: Number.isFinite(setReps.numericValue)
            && (pureBodyweight || Number.isFinite(setWeight.numericValue))

    signal completeRequested(real weightKg, int reps)
    signal editRequested()
    signal weightAdjusted(real weightKg)
    signal draftChanged(real weightKg, real reps)

    function notifyDraftChanged() {
        root.draftChanged(setWeight.numericValue, setReps.numericValue)
    }

    implicitHeight: root.active ? 64 : Design.WorkoutTheme.rowHeight
    radius: Design.WorkoutTheme.controlRadius
    color: completed ? Design.Theme.surfaceContainerLow
                     : (active ? Design.Theme.primaryContainer : "transparent")

    Behavior on color {
        ColorAnimation { duration: Design.Theme.motionFast }
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: Design.Theme.motionStandard }
    }

    Rectangle {
        visible: root.active
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        radius: 2
        color: Design.WorkoutTheme.primary
    }

    Rectangle {
        visible: root.state === "pending"
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Design.WorkoutTheme.rowDivider
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: 0
        spacing: Design.WorkoutTheme.tableColumnSpacing

        Label {
            Layout.preferredWidth: Design.WorkoutTheme.setColumnWidth
            text: root.setNumber
            color: root.active ? Design.WorkoutTheme.primaryContainerText
                               : Design.WorkoutTheme.text
            font.pixelSize: Design.WorkoutTheme.typeSetValue
            font.weight: root.active ? Font.DemiBold : Font.Normal
            font.features: ({ "tnum": 1 })
            horizontalAlignment: Text.AlignHCenter
        }

        Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.previousText.length > 0 ? root.previousText : qsTr("—")
            color: Design.WorkoutTheme.textSecondary
            font.pixelSize: Design.WorkoutTheme.typeMeta
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignLeft
        }

        NumberField {
            id: setWeight
            objectName: root.active ? "setWeightField" : ""
            Layout.preferredWidth: Design.WorkoutTheme.weightColumnWidth
            Layout.preferredHeight: Design.WorkoutTheme.inputHeight
            accessibleName: qsTr("实际重量")
            subtleBorder: root.active
            cornerRadius: Design.WorkoutTheme.controlRadius
            fillColor: root.active ? Design.Theme.surfaceContainerLowest : "transparent"
            fieldHeight: Design.WorkoutTheme.inputHeight
            textPixelSize: Design.WorkoutTheme.typeSetValue
            fontFeatures: ({ "tnum": 1 })
            textColor: Design.WorkoutTheme.text
            mutedColor: Design.WorkoutTheme.textMuted
            dividerColor: root.validationError ? Design.WorkoutTheme.danger
                                               : (root.active
                                                  ? Design.WorkoutTheme.inputBorder
                                                  : "transparent")
            outlineColor: root.active ? dividerColor : "transparent"
            focusColor: Design.WorkoutTheme.primary
            placeholderText: root.pureBodyweight ? qsTr("自重") : root.weightPlaceholder
            unit: ""
            decimals: 2
            enabled: !root.pureBodyweight && !root.submitting
            readOnly: !root.active
            verticalAdjustEnabled: !root.pureBodyweight && !root.submitting
            adjustStep: 5
            adjustThreshold: 28
            onTextChanged: {
                root.validationError = false
                root.notifyDraftChanged()
            }
            onValueAdjusted: value => root.weightAdjusted(value)
        }

        NumberField {
            id: setReps
            objectName: root.active ? "setRepsField" : ""
            visible: root.active
            Layout.preferredWidth: Design.WorkoutTheme.repsColumnWidth
            Layout.preferredHeight: Design.WorkoutTheme.inputHeight
            accessibleName: qsTr("实际次数")
            subtleBorder: true
            cornerRadius: Design.WorkoutTheme.controlRadius
            fillColor: Design.Theme.surfaceContainerLowest
            fieldHeight: Design.WorkoutTheme.inputHeight
            textPixelSize: Design.WorkoutTheme.typeSetValue
            fontFeatures: ({ "tnum": 1 })
            textColor: Design.WorkoutTheme.text
            mutedColor: Design.WorkoutTheme.textMuted
            dividerColor: root.validationError ? Design.WorkoutTheme.danger
                                               : Design.WorkoutTheme.inputBorder
            outlineColor: dividerColor
            focusColor: Design.WorkoutTheme.primary
            placeholderText: root.repsPlaceholder
            decimals: 0
            keyboardHints: Qt.ImhDigitsOnly
            enabled: !root.submitting
            onTextChanged: {
                root.validationError = false
                root.notifyDraftChanged()
            }
            onAccepted: statusButton.clicked()
        }

        Label {
            visible: !root.active
            Layout.preferredWidth: Design.WorkoutTheme.repsColumnWidth
            text: root.repsText
            color: Design.WorkoutTheme.text
            font.pixelSize: Design.WorkoutTheme.typeSetValue
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
            horizontalAlignment: Text.AlignHCenter
        }

        Button {
            id: statusButton
            objectName: root.active ? "completeSetButton" : ""
            Layout.preferredWidth: Design.WorkoutTheme.statusColumnWidth
            Layout.preferredHeight: Design.WorkoutTheme.iconTarget
            flat: true
            enabled: !root.submitting && (root.active || root.completed)
            Accessible.name: root.completed
                             ? qsTr("编辑第%1组").arg(root.setNumber)
                             : (root.active ? qsTr("完成本组")
                                            : qsTr("第%1组未完成").arg(root.setNumber))
            onClicked: {
                if (root.completed) {
                    root.editRequested()
                    return
                }
                if (!root.active)
                    return
                if (!root.inputValid) {
                    root.validationError = true
                    if (!Number.isFinite(setReps.numericValue))
                        Qt.callLater(setReps.editorItem.forceActiveFocus)
                    else if (!root.pureBodyweight)
                        Qt.callLater(setWeight.editorItem.forceActiveFocus)
                    return
                }
                root.completeRequested(root.pureBodyweight ? 0 : setWeight.numericValue,
                                       setReps.numericValue)
            }
            contentItem: Rectangle {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: root.completed ? Design.WorkoutTheme.success
                                      : (root.active ? Design.WorkoutTheme.primary
                                                     : "transparent")
                border.width: root.completed || root.active ? 0 : 1
                border.color: root.validationError ? Design.WorkoutTheme.danger
                                                   : (root.active
                                                      ? Design.WorkoutTheme.primary
                                                      : Design.WorkoutTheme.divider)

                AppIcon {
                    anchors.centerIn: parent
                    name: root.completed || root.active ? "success" : ""
                    color: root.active ? Design.WorkoutTheme.primaryForeground : "white"
                }
            }
            background: Item { }
        }
    }
}
