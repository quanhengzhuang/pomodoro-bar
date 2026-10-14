# 更新已有照片的具体地点

## 目标

让已添加的照片在地图提供具体场所名时显示更精确的地点。

## 改动

- 对已有 GPS 照片重新查询地点；只有旧名称与原自动生成的市区名称一致时才升级为兴趣点名称。
- 记录查询版本，避免每次打开行程都重复查询；保留旧数据及已有自定义名称。
- 更正无拍摄时间照片的导入提示。

## 影响文件

- `iOS/PhotoTimeline/PhotoTimeline/TripStore.swift`
- `iOS/PhotoTimeline/PhotoTimeline/ContentView.swift`
- 本 task 的中英文文档

## 预估代码行数

约 35–55 行。
