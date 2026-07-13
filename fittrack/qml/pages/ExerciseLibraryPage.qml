pragma ComponentBehavior: Bound

import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme" as Design

AppPage {
    id: page

    implicitWidth: 0

    property string feedbackMessage: ""
    property string feedbackTone: "info"
    readonly property var sourceModel: exerciseModel

    readonly property int activeFilterCount: (sourceModel.bodyPart.length > 0 ? 1 : 0)
                                               + (sourceModel.movementFilter.length > 0 ? 1 : 0)
                                               + (sourceModel.equipmentFilter.length > 0 ? 1 : 0)
                                               + (sourceModel.collectionFilter.length > 0 ? 1 : 0)
                                               + (sourceModel.favoritesOnly ? 1 : 0)
    readonly property bool hasActiveQuery: searchField.text.trim().length > 0
                                            || activeFilterCount > 0

    component FormInput: TextField {
        id: field

        implicitHeight: Design.Theme.controlHeight
        color: Design.Theme.surfaceText
        placeholderTextColor: Design.Theme.surfaceMuted
        font.pixelSize: Design.Theme.typeBody
        leftPadding: Design.Theme.space12
        rightPadding: Design.Theme.space12
        selectByMouse: true
        background: Rectangle {
            color: Design.Theme.surfaceElevated
            radius: Design.Theme.radiusSmall
            border.width: field.activeFocus ? 2 : 1
            border.color: field.activeFocus ? Design.Theme.primary : Design.Theme.outline
        }
    }

    function reportResult(succeeded, successMessage, errorMessage) {
        feedbackTone = succeeded ? "success" : "error"
        feedbackMessage = succeeded ? successMessage : errorMessage
        feedbackTimer.restart()
        return succeeded
    }

    function sourceTypeText(type) {
        switch (type) {
        case "exerciseGuide": return qsTr("动作指南")
        case "exerciseLibrary": return qsTr("动作资料库")
        case "techniqueArticle": return qsTr("技术文章")
        case "expertArticle": return qsTr("专业文章")
        case "article": return qsTr("专业文章")
        case "research": return qsTr("研究资料")
        case "researchSummary": return qsTr("研究综述")
        case "positionStand": return qsTr("立场声明")
        case "anatomyReference": return qsTr("解剖资料")
        case "manufacturerGuide": return qsTr("器械指南")
        case "manufacturerManual": return qsTr("器械手册")
        case "manufacturerReference": return qsTr("器械资料")
        default: return qsTr("参考资料")
        }
    }

    function collectionText(id) {
        const labels = {
            "tan-three-day-push": qsTr("三分化 · 推"),
            "tan-three-day-pull": qsTr("三分化 · 拉"),
            "tan-three-day-legs": qsTr("三分化 · 腿"),
            "tan-fenjue-back": qsTr("焚诀 · 背部"),
            "tan-fenjue-chest": qsTr("焚诀 · 胸部"),
            "tan-fenjue-shoulders": qsTr("焚诀 · 肩部"),
            "tan-fenjue-biceps": qsTr("焚诀 · 肱二头"),
            "tan-fenjue-triceps": qsTr("焚诀 · 肱三头"),
            "tan-fenjue-legs": qsTr("焚诀 · 腿部")
        }
        return labels[id] || id
    }

    function clearFilters(includeSearch) {
        sourceModel.bodyPart = ""
        sourceModel.movementFilter = ""
        sourceModel.equipmentFilter = ""
        sourceModel.collectionFilter = ""
        sourceModel.favoritesOnly = false
        if (includeSearch)
            searchField.text = ""
        filterDialog.syncControls()
    }

    function resetCustomDialog() {
        customDialog.editingId = ""
        customDialog.validationMessage = ""
        customName.text = ""
        customBodyPart.text = ""
        customMovement.text = ""
        customEquipment.text = ""
        customIntro.text = ""
        customSets.text = "3"
        customReps.text = "8-12"
        customRest.text = "90"
    }

    function editCurrentExercise() {
        customDialog.editingId = detailDialog.exerciseId
        customDialog.validationMessage = ""
        customName.text = detailDialog.exerciseName
        customBodyPart.text = detailDialog.primaryMuscles.length > 0
                ? detailDialog.primaryMuscles[0] : ""
        customMovement.text = detailDialog.movement
        customEquipment.text = detailDialog.equipmentText
        customIntro.text = detailDialog.introduction
        customSets.text = String(detailDialog.recommendedSets)
        customReps.text = detailDialog.recommendedReps
        customRest.text = String(detailDialog.restSeconds)
        detailDialog.close()
        customDialog.open()
    }

    function submitCustomExercise() {
        if (customName.text.trim().length === 0
                || customBodyPart.text.trim().length === 0
                || customMovement.text.trim().length === 0) {
            customDialog.validationMessage = qsTr("请填写动作名称、主要肌群和动作模式。")
            return
        }

        const sets = Number(customSets.numericValue)
        const rest = Number(customRest.numericValue)
        const succeeded = customDialog.editingId.length > 0
                ? sourceModel.updateCustomExercise(
                      customDialog.editingId,
                      customName.text,
                      customBodyPart.text,
                      customMovement.text,
                      customEquipment.text,
                      customIntro.text,
                      isNaN(sets) ? 3 : sets,
                      customReps.text,
                      isNaN(rest) ? 90 : rest)
                : sourceModel.createCustomExercise(
                      customName.text,
                      customBodyPart.text,
                      customMovement.text,
                      customEquipment.text,
                      customIntro.text,
                      isNaN(sets) ? 3 : sets,
                      customReps.text,
                      isNaN(rest) ? 90 : rest)

        if (reportResult(succeeded,
                         customDialog.editingId.length > 0
                             ? qsTr("自定义动作已更新") : qsTr("自定义动作已创建"),
                         qsTr("保存失败，请检查必填信息后重试。")))
            customDialog.close()
    }

    function openExerciseDetail(data) {
        if (data.isSystem) {
            sharedExerciseDetail.openExercise(exerciseModel.exerciseById(data.exerciseId))
            return
        }
        detailDialog.exerciseId = data.exerciseId
        detailDialog.isSystem = data.isSystem
        detailDialog.isFavorite = data.isFavorite
        detailDialog.exerciseName = data.name
        detailDialog.introduction = data.introduction
        detailDialog.steps = data.steps
        detailDialog.cautions = data.cautions
        detailDialog.difficulty = data.difficulty
        detailDialog.techniquePoints = data.techniquePoints
        detailDialog.commonMistakes = data.commonMistakes
        detailDialog.collections = data.collections
        detailDialog.primaryMuscles = data.primaryMuscles
        detailDialog.secondaryMuscles = data.secondaryMuscles
        detailDialog.mediaUrl = data.mediaUrl
        detailDialog.mediaTitle = data.mediaTitle
        detailDialog.mediaSource = data.mediaSource
        detailDialog.mediaLicense = data.mediaLicense
        detailDialog.mediaItems = data.mediaItems || []
        detailDialog.mediaIndex = 0
        detailDialog.sources = data.sources || []
        detailDialog.movement = data.movement
        detailDialog.equipmentText = data.equipmentText
        detailDialog.recommendedSets = data.recommendedSets
        detailDialog.recommendedReps = data.recommendedReps
        detailDialog.restSeconds = data.restSeconds
        detailDialog.open()
    }

    ExerciseDetailSheet {
        id: sharedExerciseDetail
        objectName: "libraryExerciseDetailSheet"
    }

    Timer {
        id: feedbackTimer
        interval: 4200
        onTriggered: page.feedbackMessage = ""
    }

    Dialog {
        id: filterDialog

        property string pendingBodyPart: ""
        property string pendingMovement: ""
        property string pendingEquipment: ""
        property string pendingCollection: ""
        property bool pendingFavoritesOnly: false
        readonly property var collectionIds: ["", "tan-three-day-push", "tan-three-day-pull",
                                              "tan-three-day-legs", "tan-fenjue-back",
                                              "tan-fenjue-chest", "tan-fenjue-shoulders",
                                              "tan-fenjue-biceps", "tan-fenjue-triceps",
                                              "tan-fenjue-legs"]

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(392, Overlay.overlay ? Overlay.overlay.width - Design.Theme.space16 * 2 : 392)
        modal: true
        focus: true
        padding: Design.Theme.space24
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        title: qsTr("筛选动作")

        function syncControls() {
            pendingBodyPart = page.sourceModel.bodyPart
            pendingMovement = page.sourceModel.movementFilter
            pendingEquipment = page.sourceModel.equipmentFilter
            pendingCollection = page.sourceModel.collectionFilter
            pendingFavoritesOnly = page.sourceModel.favoritesOnly
            bodyPartBox.currentIndex = Math.max(0, bodyPartBox.find(
                pendingBodyPart.length > 0 ? pendingBodyPart : qsTr("全部部位")))
            movementBox.currentIndex = Math.max(0, movementBox.find(
                pendingMovement.length > 0 ? pendingMovement : qsTr("全部模式")))
            equipmentBox.currentIndex = Math.max(0, equipmentBox.find(
                pendingEquipment.length > 0 ? pendingEquipment : qsTr("全部器械")))
            collectionBox.currentIndex = Math.max(0, collectionIds.indexOf(pendingCollection))
            favoritesCheck.checked = pendingFavoritesOnly
        }

        function clearPendingFilters() {
            pendingBodyPart = ""
            pendingMovement = ""
            pendingEquipment = ""
            pendingCollection = ""
            pendingFavoritesOnly = false
            bodyPartBox.currentIndex = 0
            movementBox.currentIndex = 0
            equipmentBox.currentIndex = 0
            collectionBox.currentIndex = 0
            favoritesCheck.checked = false
        }

        function applyPendingFilters() {
            page.sourceModel.bodyPart = pendingBodyPart
            page.sourceModel.movementFilter = pendingMovement
            page.sourceModel.equipmentFilter = pendingEquipment
            page.sourceModel.collectionFilter = pendingCollection
            page.sourceModel.favoritesOnly = pendingFavoritesOnly
            close()
        }

        Overlay.modal: Rectangle { color: Design.Theme.scrim }

        background: Rectangle {
            color: Design.Theme.surface
            radius: Design.Theme.radiusLarge
            border.width: 1
            border.color: Design.Theme.outline
        }

        header: Label {
            text: filterDialog.title
            color: Design.Theme.surfaceText
            font.pixelSize: Design.Theme.typeTitle
            font.weight: Font.DemiBold
            leftPadding: Design.Theme.space24
            rightPadding: Design.Theme.space24
            topPadding: Design.Theme.space24
        }

        contentItem: ColumnLayout {
            spacing: Design.Theme.space16

            Label {
                text: qsTr("训练部位")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
            }
            ComboBox {
                id: bodyPartBox
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                model: [qsTr("全部部位"), qsTr("胸部"), qsTr("背部"), qsTr("肩部"),
                        qsTr("手臂"), qsTr("臀腿")]
                onActivated: filterDialog.pendingBodyPart = currentIndex === 0 ? "" : currentText
            }

            Label {
                text: qsTr("动作模式")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
            }
            ComboBox {
                id: movementBox
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                model: [qsTr("全部模式"), qsTr("水平推"), qsTr("水平拉"), qsTr("垂直拉"),
                        qsTr("蹲"), qsTr("髋铰链")]
                onActivated: filterDialog.pendingMovement = currentIndex === 0 ? "" : currentText
            }

            Label {
                text: qsTr("使用器械")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
            }
            ComboBox {
                id: equipmentBox
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                model: [qsTr("全部器械"), qsTr("杠铃"), qsTr("哑铃"), qsTr("钢线"),
                        qsTr("固定器械"), qsTr("自重")]
                onActivated: filterDialog.pendingEquipment = currentIndex === 0 ? "" : currentText
            }

            Label {
                text: qsTr("动作集合")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
            }
            ComboBox {
                id: collectionBox
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                model: [qsTr("全部体系"), qsTr("三分化 · 推"), qsTr("三分化 · 拉"),
                        qsTr("三分化 · 腿"), qsTr("焚诀 · 背部"), qsTr("焚诀 · 胸部"),
                        qsTr("焚诀 · 肩部"), qsTr("焚诀 · 肱二头"),
                        qsTr("焚诀 · 肱三头"), qsTr("焚诀 · 腿部")]
                Accessible.name: qsTr("动作集合")
                onActivated: filterDialog.pendingCollection = filterDialog.collectionIds[currentIndex]
            }

            CheckBox {
                id: favoritesCheck
                Layout.fillWidth: true
                implicitHeight: Design.Theme.touchTarget
                text: qsTr("只看已收藏动作")
                onToggled: filterDialog.pendingFavoritesOnly = checked
            }
        }

        footer: Item {
            implicitHeight: Design.Theme.controlHeight + Design.Theme.space24

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.Theme.space24
                anchors.rightMargin: Design.Theme.space24
                anchors.bottomMargin: Design.Theme.space24
                spacing: Design.Theme.space8

                AppButton {
                    text: qsTr("清除")
                    variant: "secondary"
                    Layout.fillWidth: true
                    onClicked: filterDialog.clearPendingFilters()
                }
                AppButton {
                    text: qsTr("查看结果")
                    Layout.fillWidth: true
                    onClicked: filterDialog.applyPendingFilters()
                }
            }
        }

        onOpened: syncControls()
    }

    Dialog {
        id: detailDialog

        property string exerciseId: ""
        property bool isSystem: true
        property bool isFavorite: false
        property string exerciseName: ""
        property string introduction: ""
        property var steps: []
        property var cautions: []
        property string difficulty: ""
        property var techniquePoints: []
        property var commonMistakes: []
        property var collections: []
        property var primaryMuscles: []
        property var secondaryMuscles: []
        property string mediaUrl: ""
        property string mediaTitle: ""
        property string mediaSource: ""
        property string mediaLicense: ""
        property var mediaItems: []
        property int mediaIndex: 0
        readonly property var currentMedia: mediaItems.length > mediaIndex
                                            ? mediaItems[mediaIndex]
                                            : ({"url": mediaUrl, "title": mediaTitle,
                                                "source": mediaSource, "license": mediaLicense})
        property var sources: []
        property string movement: ""
        property string equipmentText: ""
        property int recommendedSets: 3
        property string recommendedReps: "8-12"
        property int restSeconds: 90
        readonly property Item accessibleItem: detailSurface

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Overlay.overlay ? Overlay.overlay.width - Design.Theme.space16 : 400
        height: Math.min(820, Overlay.overlay ? Overlay.overlay.height - Design.Theme.space16 : 820)
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape
        title: exerciseName.length > 0
               ? qsTr("%1动作详情").arg(exerciseName)
               : qsTr("动作详情")

        Overlay.modal: Rectangle { color: Design.Theme.scrim }

        background: Rectangle {
            id: detailSurface
            objectName: "exerciseDetailDialogSurface"
            color: Design.Theme.background
            radius: Design.Theme.radiusLarge
            border.width: 1
            border.color: Design.Theme.outline
            Accessible.role: Accessible.Dialog
            Accessible.name: detailDialog.title
            Accessible.description: detailDialog.introduction
        }

        header: Item {
            implicitHeight: 64

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.Theme.space16
                anchors.rightMargin: Design.Theme.space8
                spacing: Design.Theme.space8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space4
                    Label {
                        Layout.fillWidth: true
                        text: detailDialog.exerciseName
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeTitle
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Label {
                        Layout.fillWidth: true
                        text: detailDialog.isSystem ? qsTr("系统动作 · 只读资料") : qsTr("我的自定义动作")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeCaption
                        elide: Text.ElideRight
                    }
                }
                IconButton {
                    visible: !detailDialog.isSystem
                    glyph: "⋮"
                    accessibleName: qsTr("更多动作操作")
                    onClicked: detailMenu.popup()

                    Menu {
                        id: detailMenu
                        y: parent.height
                        MenuItem {
                            text: qsTr("编辑自定义动作")
                            onTriggered: page.editCurrentExercise()
                        }
                        MenuItem {
                            text: qsTr("删除自定义动作")
                            onTriggered: {
                                deleteDialog.exerciseId = detailDialog.exerciseId
                                deleteDialog.exerciseName = detailDialog.exerciseName
                                detailDialog.close()
                                deleteDialog.open()
                            }
                        }
                    }
                }
                IconButton {
                    id: closeDetailButton
                    glyph: "×"
                    accessibleName: qsTr("关闭动作详情")
                    onClicked: detailDialog.close()
                }
            }
        }

        contentItem: ScrollView {
            id: detailScroll
            objectName: "exerciseDetailScroll"
            clip: true
            leftPadding: Design.Theme.space16
            rightPadding: Design.Theme.space16

            ColumnLayout {
                width: detailScroll.availableWidth
                spacing: Design.Theme.space16

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(224, width * 0.62)
                    radius: Design.Theme.radiusMedium
                    color: (detailDialog.currentMedia.url || "").length > 0
                           ? Design.Theme.mediaBackdrop : Design.Theme.surface
                    border.width: 1
                    border.color: Design.Theme.outline
                    clip: true

                    Image {
                        id: detailImage
                        objectName: "exerciseDetailImage"
                        anchors.fill: parent
                        anchors.margins: Design.Theme.space8
                        source: detailDialog.currentMedia.url || ""
                        sourceSize.width: 720
                        sourceSize.height: 480
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: source.toString().length > 0 && status === Image.Ready
                        Accessible.role: Accessible.Graphic
                        Accessible.name: (detailDialog.currentMedia.title || "").length > 0
                                         ? detailDialog.currentMedia.title
                                         : qsTr("%1动作图").arg(detailDialog.exerciseName)
                        Accessible.description: qsTr("用于识别%1动作")
                                                .arg(detailDialog.exerciseName)
                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        visible: (detailDialog.currentMedia.url || "").length > 0
                                 && detailImage.status === Image.Loading
                        running: visible
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Design.Theme.space8
                        visible: (detailDialog.currentMedia.url || "").length === 0
                                 || detailImage.status === Image.Null
                                 || detailImage.status === Image.Error

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "◇"
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeDisplay
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (detailDialog.currentMedia.url || "").length > 0
                                  ? qsTr("图片暂时无法加载") : qsTr("暂无本地动作图片")
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                        }
                    }

                    IconButton {
                        anchors.left: parent.left
                        anchors.leftMargin: Design.Theme.space8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: detailDialog.mediaItems.length > 1
                        glyph: "‹"
                        accessibleName: qsTr("上一张动作图")
                        onClicked: detailDialog.mediaIndex = Math.max(0, detailDialog.mediaIndex - 1)
                    }
                    IconButton {
                        anchors.right: parent.right
                        anchors.rightMargin: Design.Theme.space8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: detailDialog.mediaItems.length > 1
                        glyph: "›"
                        accessibleName: qsTr("下一张动作图")
                        onClicked: detailDialog.mediaIndex = Math.min(
                                       detailDialog.mediaItems.length - 1,
                                       detailDialog.mediaIndex + 1)
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Design.Theme.space8
                        visible: detailDialog.mediaItems.length > 1
                        text: qsTr("%1 / %2 · %3")
                              .arg(detailDialog.mediaIndex + 1)
                              .arg(detailDialog.mediaItems.length)
                              .arg(detailDialog.mediaIndex === 0 ? qsTr("起始") : qsTr("结束"))
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeCaption
                        padding: Design.Theme.space4
                        background: Rectangle {
                            color: Design.Theme.scrim
                            radius: Design.Theme.radiusSmall
                        }
                    }
                }

                AppCard {
                    id: mediaCredit
                    objectName: "exerciseMediaCredit"
                    visible: (detailDialog.currentMedia.title || "").length > 0
                             || (detailDialog.currentMedia.source || "").length > 0
                             || (detailDialog.currentMedia.license || "").length > 0
                    Layout.fillWidth: true
                    padding: Design.Theme.space12
                    Accessible.role: Accessible.Grouping
                    Accessible.name: qsTr("图片来源")
                    Accessible.description: [
                        detailDialog.currentMedia.title || "",
                        detailDialog.currentMedia.source || "",
                        detailDialog.currentMedia.license || ""
                    ].filter(function(value) { return value.length > 0 }).join("，")

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Design.Theme.space4

                        Label {
                            visible: (detailDialog.currentMedia.title || "").length > 0
                            Layout.fillWidth: true
                            text: qsTr("素材：%1").arg(detailDialog.currentMedia.title || "")
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeLabel
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            visible: (detailDialog.currentMedia.source || "").length > 0
                            Layout.fillWidth: true
                            text: qsTr("来源：%1").arg(detailDialog.currentMedia.source || "")
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeCaption
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            visible: (detailDialog.currentMedia.license || "").length > 0
                            Layout.fillWidth: true
                            text: qsTr("许可：%1").arg(detailDialog.currentMedia.license || "")
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeCaption
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space8

                    Repeater {
                        model: detailDialog.primaryMuscles
                        delegate: Rectangle {
                            id: primaryTagContainer
                            required property var modelData
                            implicitWidth: primaryTag.implicitWidth + Design.Theme.space16
                            implicitHeight: 32
                            radius: Design.Theme.radiusSmall
                            color: Design.Theme.primaryContainer
                            Label {
                                id: primaryTag
                                anchors.centerIn: parent
                                text: primaryTagContainer.modelData
                                color: Design.Theme.primaryContainerText
                                font.pixelSize: Design.Theme.typeCaption
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                    Rectangle {
                        id: movementTagContainer
                        objectName: "exerciseMovementTag"
                        visible: detailDialog.movement.length > 0
                        implicitWidth: movementTag.implicitWidth + Design.Theme.space16
                        implicitHeight: 32
                        radius: Design.Theme.radiusSmall
                        color: Design.Theme.surfaceElevated
                        Label {
                            id: movementTag
                            anchors.centerIn: parent
                            text: detailDialog.movement
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeCaption
                        }
                    }
                    Rectangle {
                        visible: detailDialog.difficulty.length > 0
                        implicitWidth: difficultyTag.implicitWidth + Design.Theme.space16
                        implicitHeight: 32
                        radius: Design.Theme.radiusSmall
                        color: Design.Theme.surfaceElevated
                        Label {
                            id: difficultyTag
                            anchors.centerIn: parent
                            text: detailDialog.difficulty
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeCaption
                        }
                    }
                    Repeater {
                        model: detailDialog.collections
                        delegate: Rectangle {
                            id: collectionTagContainer
                            required property var modelData
                            implicitWidth: collectionTag.implicitWidth + Design.Theme.space16
                            implicitHeight: 32
                            radius: Design.Theme.radiusSmall
                            color: Design.Theme.primaryContainer
                            Label {
                                id: collectionTag
                                anchors.centerIn: parent
                                text: page.collectionText(collectionTagContainer.modelData)
                                color: Design.Theme.primaryContainerText
                                font.pixelSize: Design.Theme.typeCaption
                            }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: detailDialog.introduction.length > 0
                          ? detailDialog.introduction : qsTr("该动作暂未补充简介。")
                    color: detailDialog.introduction.length > 0
                           ? Design.Theme.surfaceText : Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeBody
                    lineHeight: 1.45
                    wrapMode: Text.WordWrap
                }

                AppCard {
                    Layout.fillWidth: true
                    padding: Design.Theme.space12

                    RowLayout {
                        anchors.fill: parent
                        spacing: Design.Theme.space8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Design.Theme.space4
                            Label { text: qsTr("建议组数"); color: Design.Theme.surfaceMuted; font.pixelSize: Design.Theme.typeCaption }
                            Label { text: qsTr("%1 组").arg(detailDialog.recommendedSets); color: Design.Theme.surfaceText; font.pixelSize: Design.Theme.typeBody; font.weight: Font.Bold }
                        }
                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Design.Theme.outline }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Design.Theme.space4
                            Label { text: qsTr("建议次数"); color: Design.Theme.surfaceMuted; font.pixelSize: Design.Theme.typeCaption }
                            Label { text: detailDialog.recommendedReps.length > 0 ? detailDialog.recommendedReps : qsTr("未设置"); color: Design.Theme.surfaceText; font.pixelSize: Design.Theme.typeBody; font.weight: Font.Bold }
                        }
                        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Design.Theme.outline }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Design.Theme.space4
                            Label { text: qsTr("建议间歇"); color: Design.Theme.surfaceMuted; font.pixelSize: Design.Theme.typeCaption }
                            Label { text: qsTr("%1 秒").arg(detailDialog.restSeconds); color: Design.Theme.surfaceText; font.pixelSize: Design.Theme.typeBody; font.weight: Font.Bold }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space8
                    Label {
                        text: qsTr("刺激肌群")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("主要：%1").arg(detailDialog.primaryMuscles.length > 0
                                                     ? detailDialog.primaryMuscles.join("、") : qsTr("未标注"))
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeLabel
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("次要：%1").arg(detailDialog.secondaryMuscles.length > 0
                                                     ? detailDialog.secondaryMuscles.join("、") : qsTr("未标注"))
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeLabel
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("器械：%1").arg(detailDialog.equipmentText.length > 0
                                                     ? detailDialog.equipmentText : qsTr("无需特定器械"))
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeLabel
                        wrapMode: Text.WordWrap
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space12
                    visible: detailDialog.techniquePoints.length > 0
                    Label {
                        text: qsTr("发力要点")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                    }
                    Repeater {
                        model: detailDialog.techniquePoints
                        delegate: RowLayout {
                            id: techniqueRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: Design.Theme.space12
                            Label {
                                text: "•"
                                color: Design.Theme.primary
                                font.pixelSize: Design.Theme.typeBody
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Label {
                                Layout.fillWidth: true
                                text: techniqueRow.modelData
                                color: Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeLabel
                                lineHeight: 1.4
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space12
                    Label {
                        text: qsTr("动作步骤")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                    }
                    Repeater {
                        model: detailDialog.steps
                        delegate: RowLayout {
                            id: stepRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: Design.Theme.space12
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                color: Design.Theme.primaryContainer
                                Label {
                                    anchors.centerIn: parent
                                    text: stepRow.index + 1
                                    color: Design.Theme.primaryContainerText
                                    font.pixelSize: Design.Theme.typeCaption
                                    font.weight: Font.Bold
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                text: stepRow.modelData
                                color: Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeLabel
                                lineHeight: 1.4
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    Label {
                        visible: detailDialog.steps.length === 0
                        Layout.fillWidth: true
                        text: qsTr("该动作暂未补充分步教学。")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeLabel
                        wrapMode: Text.WordWrap
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space12
                    Label {
                        text: qsTr("关键注意点")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                    }
                    Repeater {
                        model: detailDialog.cautions
                        delegate: RowLayout {
                            id: cautionRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: Design.Theme.space12
                            Label {
                                text: "!"
                                color: Design.Theme.warning
                                font.pixelSize: Design.Theme.typeBody
                                font.weight: Font.Bold
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Label {
                                Layout.fillWidth: true
                                text: cautionRow.modelData
                                color: Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeLabel
                                lineHeight: 1.4
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                    Label {
                        visible: detailDialog.cautions.length === 0
                        Layout.fillWidth: true
                        text: qsTr("该动作暂未补充注意点。")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeLabel
                        wrapMode: Text.WordWrap
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space12
                    visible: detailDialog.commonMistakes.length > 0
                    Label {
                        text: qsTr("常见错误")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                    }
                    Repeater {
                        model: detailDialog.commonMistakes
                        delegate: RowLayout {
                            id: mistakeRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: Design.Theme.space12
                            Label {
                                text: "×"
                                color: Design.Theme.error
                                font.pixelSize: Design.Theme.typeBody
                                font.weight: Font.Bold
                                Layout.preferredWidth: 20
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Label {
                                Layout.fillWidth: true
                                text: mistakeRow.modelData
                                color: Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeLabel
                                lineHeight: 1.4
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: referenceSection
                    objectName: "exerciseReferenceSection"
                    visible: detailDialog.sources.length > 0
                    Layout.fillWidth: true
                    spacing: Design.Theme.space8
                    Accessible.role: Accessible.Grouping
                    Accessible.name: qsTr("参考资料")

                    Label {
                        text: qsTr("参考资料")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("动作内容由以下专业资料交叉整理。")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeCaption
                        wrapMode: Text.WordWrap
                    }
                    Repeater {
                        model: detailDialog.sources
                        delegate: AppCard {
                            id: sourceCard
                            required property var modelData
                            Layout.fillWidth: true
                            padding: Design.Theme.space12

                            RowLayout {
                                anchors.fill: parent
                                spacing: Design.Theme.space8

                                Rectangle {
                                    implicitWidth: sourceTypeLabel.implicitWidth + Design.Theme.space16
                                    implicitHeight: Math.max(32,
                                                             sourceTypeLabel.implicitHeight
                                                             + Design.Theme.space8)
                                    radius: Design.Theme.radiusSmall
                                    color: Design.Theme.surfaceElevated
                                    Label {
                                        id: sourceTypeLabel
                                        anchors.centerIn: parent
                                        text: page.sourceTypeText(sourceCard.modelData.type || "")
                                        color: Design.Theme.surfaceMuted
                                        font.pixelSize: Design.Theme.typeCaption
                                    }
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: sourceCard.modelData.title || qsTr("未命名资料")
                                    color: Design.Theme.surfaceText
                                    font.pixelSize: Design.Theme.typeLabel
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Design.Theme.space8 }
            }
        }

        footer: Item {
            implicitHeight: Design.Theme.controlHeight + Design.Theme.space24

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.Theme.space16
                anchors.rightMargin: Design.Theme.space16
                anchors.topMargin: Design.Theme.space8
                anchors.bottomMargin: Design.Theme.space16
                spacing: Design.Theme.space8

                AppButton {
                    Layout.fillWidth: true
                    text: detailDialog.isFavorite ? qsTr("已收藏") : qsTr("收藏动作")
                    variant: detailDialog.isFavorite ? "secondary" : "primary"
                    onClicked: {
                        const succeeded = page.sourceModel.toggleFavorite(detailDialog.exerciseId)
                        if (succeeded)
                            detailDialog.isFavorite = !detailDialog.isFavorite
                        page.reportResult(succeeded,
                                          detailDialog.isFavorite ? qsTr("动作已收藏") : qsTr("已取消收藏"),
                                          qsTr("收藏状态更新失败，请重试。"))
                    }
                }
            }
        }

        onOpened: Qt.callLater(function() {
            closeDetailButton.forceActiveFocus()
        })
    }

    Dialog {
        id: customDialog

        property string editingId: ""
        property string validationMessage: ""

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Overlay.overlay ? Overlay.overlay.width - Design.Theme.space16 : 400
        height: Math.min(760, Overlay.overlay ? Overlay.overlay.height - Design.Theme.space24 : 760)
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape
        title: editingId.length > 0 ? qsTr("编辑自定义动作") : qsTr("新建自定义动作")

        Overlay.modal: Rectangle { color: Design.Theme.scrim }

        background: Rectangle {
            color: Design.Theme.background
            radius: Design.Theme.radiusLarge
            border.width: 1
            border.color: Design.Theme.outline
        }

        header: Item {
            implicitHeight: 64

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.Theme.space16
                anchors.rightMargin: Design.Theme.space8
                Label {
                    Layout.fillWidth: true
                    text: customDialog.title
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeTitle
                    font.weight: Font.Bold
                }
                IconButton {
                    glyph: "×"
                    accessibleName: qsTr("取消编辑")
                    onClicked: customDialog.close()
                }
            }
        }

        contentItem: ScrollView {
            id: customScroll
            clip: true
            leftPadding: Design.Theme.space16
            rightPadding: Design.Theme.space16

            ColumnLayout {
                width: customScroll.availableWidth
                spacing: Design.Theme.space12

                InlineFeedback {
                    visible: customDialog.validationMessage.length > 0
                    Layout.fillWidth: true
                    tone: "error"
                    message: customDialog.validationMessage
                }

                Label { text: qsTr("动作名称 *"); color: Design.Theme.surfaceMuted; font.pixelSize: Design.Theme.typeLabel }
                FormInput {
                    id: customName
                    Layout.fillWidth: true
                    placeholderText: qsTr("例如：学校健身房推胸机")
                    Accessible.name: qsTr("动作名称")
                }

                Label { text: qsTr("主要肌群 *"); color: Design.Theme.surfaceMuted; font.pixelSize: Design.Theme.typeLabel }
                FormInput {
                    id: customBodyPart
                    Layout.fillWidth: true
                    placeholderText: qsTr("例如：上胸")
                    Accessible.name: qsTr("主要肌群")
                }

                Label { text: qsTr("动作模式 *"); color: Design.Theme.surfaceMuted; font.pixelSize: Design.Theme.typeLabel }
                FormInput {
                    id: customMovement
                    Layout.fillWidth: true
                    placeholderText: qsTr("例如：水平推")
                    Accessible.name: qsTr("动作模式")
                }

                Label { text: qsTr("使用器械"); color: Design.Theme.surfaceMuted; font.pixelSize: Design.Theme.typeLabel }
                FormInput {
                    id: customEquipment
                    Layout.fillWidth: true
                    placeholderText: qsTr("例如：固定器械")
                    Accessible.name: qsTr("使用器械")
                }

                Label { text: qsTr("动作简介"); color: Design.Theme.surfaceMuted; font.pixelSize: Design.Theme.typeLabel }
                TextArea {
                    id: customIntro
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    placeholderText: qsTr("记录动作方法或器械设置，可选")
                    color: Design.Theme.surfaceText
                    placeholderTextColor: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeBody
                    wrapMode: TextEdit.Wrap
                    background: Rectangle {
                        color: Design.Theme.surfaceElevated
                        radius: Design.Theme.radiusSmall
                        border.width: customIntro.activeFocus ? 2 : 1
                        border.color: customIntro.activeFocus ? Design.Theme.primary : Design.Theme.outline
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space8
                    NumberField {
                        id: customSets
                        Layout.fillWidth: true
                        label: qsTr("建议组数")
                        unit: qsTr("组")
                        from: 1
                        to: 20
                        decimals: 0
                    }
                    NumberField {
                        id: customRest
                        Layout.fillWidth: true
                        label: qsTr("建议间歇")
                        unit: qsTr("秒")
                        from: 0
                        to: 600
                        decimals: 0
                    }
                }

                Label { text: qsTr("建议次数"); color: Design.Theme.surfaceMuted; font.pixelSize: Design.Theme.typeLabel }
                FormInput {
                    id: customReps
                    Layout.fillWidth: true
                    placeholderText: qsTr("例如：8-12")
                    Accessible.name: qsTr("建议次数")
                }

                Label {
                    Layout.fillWidth: true
                    text: qsTr("自定义动作可以随时修改；系统内置动作保持只读。")
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeCaption
                    wrapMode: Text.WordWrap
                }
                Item { Layout.preferredHeight: Design.Theme.space8 }
            }
        }

        footer: Item {
            implicitHeight: Design.Theme.controlHeight + Design.Theme.space24

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.Theme.space16
                anchors.rightMargin: Design.Theme.space16
                anchors.topMargin: Design.Theme.space8
                anchors.bottomMargin: Design.Theme.space16
                spacing: Design.Theme.space8

                AppButton {
                    text: qsTr("取消")
                    variant: "secondary"
                    Layout.fillWidth: true
                    onClicked: customDialog.close()
                }
                AppButton {
                    text: customDialog.editingId.length > 0 ? qsTr("保存修改") : qsTr("创建动作")
                    Layout.fillWidth: true
                    onClicked: page.submitCustomExercise()
                }
            }
        }

        onOpened: customName.forceActiveFocus()
    }

    ConfirmDialog {
        id: deleteDialog

        property string exerciseId: ""
        property string exerciseName: ""

        title: qsTr("删除自定义动作？")
        message: qsTr("“%1”会从动作库中移除。已有训练或计划引用时，历史数据仍会保留。")
                 .arg(exerciseName)
        confirmText: qsTr("删除")
        cancelText: qsTr("取消")
        destructive: true
        onAccepted: page.reportResult(
                        page.sourceModel.deleteCustomExercise(exerciseId),
                        qsTr("自定义动作已删除"),
                        qsTr("删除失败，该动作可能正在被使用。"))
    }

    ConfirmDialog {
        id: restoreDialog

        title: qsTr("恢复系统动作资料？")
        message: qsTr("系统内置动作会恢复为随应用提供的版本。自定义动作、收藏和历史训练不会被删除。")
        confirmText: qsTr("恢复资料")
        cancelText: qsTr("取消")
        onAccepted: page.reportResult(
                        page.sourceModel.restoreSystemExercises(),
                        qsTr("系统动作资料已恢复"),
                        qsTr("恢复失败，请稍后重试。"))
    }

    Menu {
        id: pageMenu
        MenuItem {
            text: qsTr("恢复系统动作资料")
            onTriggered: restoreDialog.open()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.Theme.space12

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.Theme.space8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space4
                Label {
                    Layout.fillWidth: true
                    text: qsTr("动作资料库")
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeTitle
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("查动作要点，按训练条件快速筛选")
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeCaption
                    elide: Text.ElideRight
                }
            }

            AppButton {
                text: qsTr("新建")
                Layout.preferredWidth: 84
                onClicked: {
                    page.resetCustomDialog()
                    customDialog.open()
                }
            }
            IconButton {
                glyph: "⋮"
                accessibleName: qsTr("动作库更多操作")
                onClicked: pageMenu.popup()
            }
        }

        InlineFeedback {
            visible: page.feedbackMessage.length > 0
            Layout.fillWidth: true
            tone: page.feedbackTone
            message: page.feedbackMessage
            actionText: qsTr("关闭")
            onActionTriggered: page.feedbackMessage = ""
        }

        TextField {
            id: searchField

            Layout.fillWidth: true
            implicitHeight: Design.Theme.controlHeight
            placeholderText: qsTr("搜索动作、英文名或别名")
            color: Design.Theme.surfaceText
            placeholderTextColor: Design.Theme.surfaceMuted
            font.pixelSize: Design.Theme.typeBody
            leftPadding: Design.Theme.space16
            rightPadding: Design.Theme.space16
            selectByMouse: true
            inputMethodHints: Qt.ImhNoPredictiveText
            Accessible.name: qsTr("搜索动作")
            background: Rectangle {
                color: Design.Theme.surface
                radius: Design.Theme.radiusSmall
                border.width: searchField.activeFocus ? 2 : 1
                border.color: searchField.activeFocus ? Design.Theme.primary : Design.Theme.outline
            }
            onTextChanged: {
                if (page.sourceModel.searchText !== text)
                    page.sourceModel.searchText = text
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.Theme.space8

            AppButton {
                text: page.activeFilterCount > 0
                      ? qsTr("筛选 · %1").arg(page.activeFilterCount) : qsTr("筛选")
                variant: "secondary"
                Layout.preferredWidth: 112
                onClicked: filterDialog.open()
            }
            Label {
                Layout.fillWidth: true
                text: page.hasActiveQuery
                      ? qsTr("找到 %1 个匹配动作").arg(exerciseList.count)
                      : qsTr("共 %1 个动作").arg(exerciseList.count)
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }

        ListView {
            id: exerciseList

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Design.Theme.space8
            model: page.sourceModel
            boundsBehavior: Flickable.StopAtBounds

            delegate: ItemDelegate {
                id: exerciseDelegate

                required property string name
                required property string bodyPart
                required property string movement
                required property int recommendedSets
                required property string recommendedReps
                required property int restSeconds
                required property string introduction
                required property var steps
                required property var cautions
                required property string difficulty
                required property var techniquePoints
                required property var commonMistakes
                required property var collections
                required property var primaryMuscles
                required property var secondaryMuscles
                required property string mediaUrl
                required property string mediaTitle
                required property string mediaSource
                required property string mediaLicense
                required property var mediaItems
                required property var sources
                required property string exerciseId
                required property bool isSystem
                required property bool isFavorite
                required property string equipmentText

                function openDetail() {
                    page.openExerciseDetail({
                        "exerciseId": exerciseId,
                        "name": name,
                        "isSystem": isSystem,
                        "isFavorite": isFavorite,
                        "introduction": introduction,
                        "steps": steps,
                        "cautions": cautions,
                        "difficulty": difficulty,
                        "techniquePoints": techniquePoints,
                        "commonMistakes": commonMistakes,
                        "collections": collections,
                        "primaryMuscles": primaryMuscles,
                        "secondaryMuscles": secondaryMuscles,
                        "mediaUrl": mediaUrl,
                        "mediaTitle": mediaTitle,
                        "mediaSource": mediaSource,
                        "mediaLicense": mediaLicense,
                        "mediaItems": mediaItems,
                        "sources": sources,
                        "movement": movement,
                        "equipmentText": equipmentText,
                        "recommendedSets": recommendedSets,
                        "recommendedReps": recommendedReps,
                        "restSeconds": restSeconds
                    })
                }

                width: exerciseList.width
                implicitHeight: 104
                leftPadding: Design.Theme.space12
                rightPadding: Design.Theme.space12
                topPadding: Design.Theme.space12
                bottomPadding: Design.Theme.space12
                Accessible.name: name
                Accessible.role: Accessible.Button
                Accessible.description: qsTr("%1，%2，建议%3组%4")
                                        .arg(bodyPart).arg(movement)
                                        .arg(recommendedSets).arg(recommendedReps)
                Accessible.onPressAction: openDetail()

                background: Rectangle {
                    color: exerciseDelegate.down ? Design.Theme.surfacePressed : Design.Theme.surface
                    radius: Design.Theme.radiusMedium
                    border.width: exerciseDelegate.activeFocus ? 2 : 1
                    border.color: exerciseDelegate.activeFocus ? Design.Theme.primary : Design.Theme.outline
                }

                contentItem: RowLayout {
                    spacing: Design.Theme.space12

                    Rectangle {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 72
                        radius: Design.Theme.radiusSmall
                        color: Design.Theme.surfaceElevated
                        clip: true

                        Image {
                            id: thumbnail
                            anchors.fill: parent
                            anchors.margins: Design.Theme.space4
                            source: exerciseDelegate.mediaUrl
                            sourceSize.width: 144
                            sourceSize.height: 144
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: exerciseDelegate.mediaUrl.length > 0 && status === Image.Ready
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: !thumbnail.visible
                            text: exerciseDelegate.name.length > 0 ? exerciseDelegate.name.charAt(0) : "◇"
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeTitle
                            font.weight: Font.Bold
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Design.Theme.space4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Design.Theme.space4
                            Label {
                                Layout.fillWidth: true
                                text: exerciseDelegate.name
                                color: Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeBody
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Label {
                                visible: exerciseDelegate.isFavorite
                                text: "★"
                                color: Design.Theme.primary
                                font.pixelSize: Design.Theme.typeBody
                                Accessible.name: qsTr("已收藏")
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: [exerciseDelegate.bodyPart, exerciseDelegate.movement]
                                  .filter(function(value) { return value.length > 0 }).join(" · ")
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("%1组 · %2 · %3秒")
                                  .arg(exerciseDelegate.recommendedSets)
                                  .arg(exerciseDelegate.recommendedReps.length > 0
                                       ? exerciseDelegate.recommendedReps : qsTr("未设次数"))
                                  .arg(exerciseDelegate.restSeconds)
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeCaption
                            elide: Text.ElideRight
                        }
                    }

                    Label {
                        text: "›"
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeTitle
                    }
                }

                onClicked: openDetail()
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - Design.Theme.space24 * 2, 300)
                spacing: Design.Theme.space12
                visible: exerciseList.count === 0

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: page.hasActiveQuery ? "⌕" : "◇"
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeDisplay
                }
                Label {
                    Layout.fillWidth: true
                    text: page.hasActiveQuery ? qsTr("没有匹配的动作") : qsTr("动作资料暂不可用")
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeBody
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Label {
                    Layout.fillWidth: true
                    text: page.hasActiveQuery
                          ? qsTr("尝试清除筛选，或使用其他动作名称搜索。")
                          : qsTr("请重新加载资料；也可以先创建自己的动作。")
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeLabel
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                AppButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: page.hasActiveQuery ? qsTr("清除搜索与筛选") : qsTr("重新加载")
                    variant: "secondary"
                    onClicked: {
                        if (page.hasActiveQuery)
                            page.clearFilters(true)
                        else
                            page.sourceModel.reload()
                    }
                }
            }
        }
    }

    Connections {
        target: page.sourceModel
        function onSearchTextChanged() {
            if (!searchField.activeFocus && searchField.text !== page.sourceModel.searchText)
                searchField.text = page.sourceModel.searchText
        }
    }

    Component.onCompleted: searchField.text = page.sourceModel.searchText
}
