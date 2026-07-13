import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../components"
import "../theme" as Design

AppPage {
    id: page
    implicitWidth: 0
    leftPadding: SafeArea.margins.left
    rightPadding: SafeArea.margins.right
    topPadding: SafeArea.margins.top
    bottomPadding: SafeArea.margins.bottom

    property string editId: ""
    property string feedbackMessage: ""
    property string feedbackTone: "success"

    function localPath(url) { return url.toString() }

    Dialog {
        id: gymDialog
        property string formError: ""

        function submit() {
            const normalizedName = gymName.text.trim()
            if (!normalizedName.length) {
                formError = qsTr("请输入健身房名称")
                gymName.forceActiveFocus()
                return
            }
            const saved = page.editId.length
                ? gymManagement.renameGym(page.editId, normalizedName)
                : gymManagement.createGym(normalizedName)
            if (!saved) {
                formError = gymManagement.errorMessage.length
                    ? gymManagement.errorMessage : qsTr("保存失败，请重试")
                return
            }
            formError = ""
            gymName.clear()
            page.editId = ""
            close()
        }

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(Overlay.overlay.width - Design.Theme.space16 * 2, 420)
        title: page.editId.length ? qsTr("重命名健身房") : qsTr("新建健身房")
        onOpened: formError = ""
        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space8
            TextField {
                id: gymName
                Layout.fillWidth: true
                placeholderText: qsTr("健身房名称")
                onAccepted: gymDialog.submit()
            }
            InlineFeedback {
                visible: gymDialog.formError.length > 0
                Layout.fillWidth: true
                tone: "error"
                message: gymDialog.formError
            }
        }
        footer: Item {
            implicitHeight: Design.Theme.controlHeight + Design.Theme.space16
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.Theme.space16
                anchors.rightMargin: Design.Theme.space16
                anchors.bottomMargin: Design.Theme.space8
                spacing: Design.Theme.space8
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("取消")
                    variant: "secondary"
                    onClicked: gymDialog.reject()
                }
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("保存")
                    onClicked: gymDialog.submit()
                }
            }
        }
    }

    Dialog {
        id: equipmentDialog
        property string formError: ""

        function submit() {
            const normalizedName = equipmentName.text.trim()
            if (!normalizedName.length) {
                formError = qsTr("请输入器械名称")
                equipmentName.forceActiveFocus()
                return
            }
            const saved = page.editId.length
                ? gymManagement.updateEquipment(page.editId, normalizedName,
                                                equipmentCode.text, equipmentNotes.text)
                : gymManagement.createEquipment(normalizedName,
                                                equipmentCode.text, equipmentNotes.text)
            if (!saved) {
                formError = gymManagement.errorMessage.length
                    ? gymManagement.errorMessage : qsTr("保存失败，请重试")
                return
            }
            formError = ""
            equipmentName.clear()
            equipmentCode.clear()
            equipmentNotes.clear()
            page.editId = ""
            close()
        }

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(Overlay.overlay.width - Design.Theme.space16 * 2, 420)
        title: page.editId.length ? qsTr("编辑器械") : qsTr("新增器械")
        onOpened: formError = ""
        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space8
            TextField {
                id: equipmentName
                Layout.fillWidth: true
                placeholderText: qsTr("器械名称")
                onAccepted: equipmentDialog.submit()
            }
            TextField { id: equipmentCode; Layout.fillWidth: true; placeholderText: qsTr("编号（选填）") }
            TextArea { id: equipmentNotes; Layout.fillWidth: true; placeholderText: qsTr("座椅档位、把手等（选填）"); wrapMode: TextEdit.Wrap }
            InlineFeedback {
                visible: equipmentDialog.formError.length > 0
                Layout.fillWidth: true
                tone: "error"
                message: equipmentDialog.formError
            }
        }
        footer: Item {
            implicitHeight: Design.Theme.controlHeight + Design.Theme.space16
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.Theme.space16
                anchors.rightMargin: Design.Theme.space16
                anchors.bottomMargin: Design.Theme.space8
                spacing: Design.Theme.space8
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("取消")
                    variant: "secondary"
                    onClicked: equipmentDialog.reject()
                }
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("保存")
                    onClicked: equipmentDialog.submit()
                }
            }
        }
    }

    FileDialog {
        id: exportJsonDialog
        title: qsTr("导出JSON备份")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("FitTrack JSON (*.json)")]
        onAccepted: {
            if (backupService.exportJson(page.localPath(selectedFile))) {
                page.feedbackTone = "success"
                page.feedbackMessage = qsTr("JSON 备份已导出")
            }
        }
    }
    FileDialog {
        id: exportDbDialog
        title: qsTr("导出SQLite快照")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("SQLite数据库 (*.sqlite)")]
        onAccepted: {
            if (backupService.exportDatabase(page.localPath(selectedFile))) {
                page.feedbackTone = "success"
                page.feedbackMessage = qsTr("SQLite 快照已导出")
            }
        }
    }
    FileDialog {
        id: restoreDialog
        title: qsTr("恢复JSON备份")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("FitTrack JSON (*.json)")]
        onAccepted: {
            if (backupService.restoreJson(page.localPath(selectedFile))) {
                page.feedbackTone = "success"
                page.feedbackMessage = qsTr("备份恢复完成")
            }
        }
    }

    ConfirmDialog {
        id: deleteGymDialog
        property string gymId: ""
        title: qsTr("删除这个健身房？")
        message: qsTr("未被历史使用的数据会删除；已被引用的场地会归档并保留历史。")
        confirmText: qsTr("删除健身房")
        destructive: true
        onAccepted: gymManagement.removeGym(gymId)
    }

    ConfirmDialog {
        id: deleteEquipmentDialog
        property string equipmentId: ""
        title: qsTr("删除这台器械？")
        message: qsTr("已被训练记录引用的器械会归档，历史数据不会丢失。")
        confirmText: qsTr("删除器械")
        destructive: true
        onAccepted: gymManagement.removeEquipment(equipmentId)
    }

    ConfirmDialog {
        id: restoreConfirmDialog
        title: qsTr("从 JSON 恢复？")
        message: qsTr("恢复会替换当前本地业务数据。请先导出最新备份，再选择要恢复的 JSON 文件。")
        confirmText: qsTr("选择备份文件")
        destructive: true
        onAccepted: restoreDialog.open()
    }

    ScrollView {
        id: managementScroll
        anchors.fill: parent
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: managementScroll.availableWidth
            spacing: Design.Theme.space12

            Item { Layout.preferredHeight: 14 }

            SectionHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                eyebrow: qsTr("SETUP")
                title: qsTr("场地与数据")
                subtitle: qsTr("保存同一健身房、同一器械的数据，趋势才有比较意义。")
            }

            AppCard {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("健身房与器械")
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeBody
                            font.weight: Font.DemiBold
                        }
                        ActionPill {
                            text: qsTr("新建")
                            accent: true
                            onClicked: {
                                page.editId = ""
                                gymName.text = ""
                                gymDialog.open()
                            }
                        }
                    }

                    ComboBox {
                        Layout.fillWidth: true
                        model: gymManagement.gyms
                        textRole: "name"
                        valueRole: "id"
                        onActivated: gymManagement.selectGym(currentValue)
                    }

                    RowLayout {
                        visible: gymManagement.selectedGymId.length > 0
                        Layout.fillWidth: true
                        spacing: 8
                        ActionPill {
                            Layout.fillWidth: true
                            text: qsTr("重命名")
                            onClicked: {
                                page.editId = gymManagement.selectedGymId
                                const gym = gymManagement.gyms.find(item => item.id === page.editId)
                                gymName.text = gym ? gym.name : ""
                                gymDialog.open()
                            }
                        }
                        ActionPill {
                            Layout.fillWidth: true
                            text: qsTr("删除")
                            destructive: true
                            onClicked: {
                                deleteGymDialog.gymId = gymManagement.selectedGymId
                                deleteGymDialog.open()
                            }
                        }
                        ActionPill {
                            Layout.fillWidth: true
                            text: qsTr("加器械")
                            accent: true
                            onClicked: {
                                page.editId = ""
                                equipmentName.text = ""
                                equipmentCode.text = ""
                                equipmentNotes.text = ""
                                equipmentDialog.open()
                            }
                        }
                    }

                    Label {
                        visible: gymManagement.gyms.length === 0
                        text: qsTr("先创建一个健身房，再添加具体器械。")
                        color: Design.Theme.surfaceMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Repeater {
                model: gymManagement.equipment
                delegate: AppCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label {
                                text: modelData.name + (modelData.code.length ? " · " + modelData.code : "")
                                color: Design.Theme.surfaceText
                                font.weight: Font.DemiBold
                                font.pixelSize: Design.Theme.typeBody
                            }
                            Label {
                                visible: modelData.notes.length > 0
                                text: modelData.notes
                                color: Design.Theme.surfaceMuted
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                        IconButton {
                            glyph: "✎"
                            accessibleName: qsTr("编辑器械")
                            onClicked: {
                                page.editId = modelData.id
                                equipmentName.text = modelData.name
                                equipmentCode.text = modelData.code
                                equipmentNotes.text = modelData.notes
                                equipmentDialog.open()
                            }
                        }
                        IconButton {
                            glyph: "×"
                            destructive: true
                            accessibleName: qsTr("删除器械")
                            onClicked: {
                                deleteEquipmentDialog.equipmentId = modelData.id
                                deleteEquipmentDialog.open()
                            }
                        }
                    }
                }
            }

            AppCard {
                visible: gymManagement.gyms.length > 0
                         && gymManagement.equipment.length === 0
                Layout.fillWidth: true
                Layout.leftMargin: Design.Theme.space16
                Layout.rightMargin: Design.Theme.space16

                Label {
                    anchors.fill: parent
                    text: qsTr("这个健身房还没有器械，可以先添加一台常用设备。")
                    color: Design.Theme.surfaceMuted
                    wrapMode: Text.WordWrap
                }
            }

            AppCard {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Label {
                        text: qsTr("数据备份")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("JSON用于完整恢复；SQLite快照用于原始数据留档。恢复JSON会替换当前本地数据。")
                        color: Design.Theme.surfaceMuted
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        ActionPill { Layout.fillWidth: true; text: qsTr("导出JSON"); onClicked: exportJsonDialog.open() }
                        ActionPill { Layout.fillWidth: true; text: qsTr("导出SQLite"); onClicked: exportDbDialog.open() }
                    }
                    ActionPill {
                        Layout.fillWidth: true
                        text: qsTr("从JSON恢复")
                        accent: true
                        onClicked: restoreConfirmDialog.open()
                    }
                }
            }

            InlineFeedback {
                visible: backupService.errorMessage.length > 0 || gymManagement.errorMessage.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                tone: "error"
                message: backupService.errorMessage.length
                         ? backupService.errorMessage : gymManagement.errorMessage
            }

            InlineFeedback {
                visible: page.feedbackMessage.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                tone: page.feedbackTone
                message: page.feedbackMessage
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
