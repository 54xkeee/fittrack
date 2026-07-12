import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../components"

Page {
    id: page
    implicitWidth: 0
    background: Rectangle { color: "#0F0F0F" }

    property string editId: ""

    function localPath(url) { return url.toString() }

    Dialog {
        id: gymDialog
        anchors.centerIn: parent
        width: Math.min(page.width - 24, 420)
        title: page.editId.length ? qsTr("重命名健身房") : qsTr("新建健身房")
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: page.editId.length
            ? gymManagement.renameGym(page.editId, gymName.text)
            : gymManagement.createGym(gymName.text)
        TextField { id: gymName; anchors.fill: parent; placeholderText: qsTr("健身房名称") }
    }

    Dialog {
        id: equipmentDialog
        anchors.centerIn: parent
        width: Math.min(page.width - 24, 420)
        title: page.editId.length ? qsTr("编辑器械") : qsTr("新增器械")
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: page.editId.length
            ? gymManagement.updateEquipment(page.editId, equipmentName.text, equipmentCode.text, equipmentNotes.text)
            : gymManagement.createEquipment(equipmentName.text, equipmentCode.text, equipmentNotes.text)
        ColumnLayout {
            anchors.fill: parent
            TextField { id: equipmentName; Layout.fillWidth: true; placeholderText: qsTr("器械名称") }
            TextField { id: equipmentCode; Layout.fillWidth: true; placeholderText: qsTr("编号（选填）") }
            TextArea { id: equipmentNotes; Layout.fillWidth: true; placeholderText: qsTr("座椅档位、把手等（选填）"); wrapMode: TextEdit.Wrap }
        }
    }

    FileDialog {
        id: exportJsonDialog
        title: qsTr("导出JSON备份")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("FitTrack JSON (*.json)")]
        onAccepted: backupService.exportJson(page.localPath(selectedFile))
    }
    FileDialog {
        id: exportDbDialog
        title: qsTr("导出SQLite快照")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("SQLite数据库 (*.sqlite)")]
        onAccepted: backupService.exportDatabase(page.localPath(selectedFile))
    }
    FileDialog {
        id: restoreDialog
        title: qsTr("恢复JSON备份")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("FitTrack JSON (*.json)")]
        onAccepted: backupService.restoreJson(page.localPath(selectedFile))
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: page.width
            spacing: 12

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
                            color: "#F3F0EF"
                            font.pixelSize: 18
                            font.bold: true
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
                            onClicked: gymManagement.removeGym(gymManagement.selectedGymId)
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
                        color: "#A8AAA9"
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
                                color: "#F3F0EF"
                                font.bold: true
                                font.pixelSize: 16
                            }
                            Label {
                                visible: modelData.notes.length > 0
                                text: modelData.notes
                                color: "#A8AAA9"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                        ToolButton {
                            text: qsTr("编辑")
                            onClicked: {
                                page.editId = modelData.id
                                equipmentName.text = modelData.name
                                equipmentCode.text = modelData.code
                                equipmentNotes.text = modelData.notes
                                equipmentDialog.open()
                            }
                        }
                        ToolButton { text: qsTr("删除"); onClicked: gymManagement.removeEquipment(modelData.id) }
                    }
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
                        color: "#F3F0EF"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("JSON用于完整恢复；SQLite快照用于原始数据留档。恢复JSON会替换当前本地数据。")
                        color: "#A8AAA9"
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
                        onClicked: restoreDialog.open()
                    }
                }
            }

            Label {
                visible: backupService.errorMessage.length > 0 || gymManagement.errorMessage.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                text: backupService.errorMessage.length ? backupService.errorMessage : gymManagement.errorMessage
                color: "#FF8A80"
                wrapMode: Text.WordWrap
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
