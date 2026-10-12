import SwiftUI
import PhotosUI
import CoreLocation

private enum Palette {
    static let ink = Color(red: 0.08, green: 0.18, blue: 0.23)
    static let blue = Color(red: 0.18, green: 0.43, blue: 0.53)
    static let mist = Color(red: 0.91, green: 0.95, blue: 0.95)
    static let paper = Color(red: 0.98, green: 0.99, blue: 0.98)
    static let coral = Color(red: 0.96, green: 0.40, blue: 0.30)
    static let warning = Color(red: 0.58, green: 0.39, blue: 0.05)
    static let shortInterval = Color(red: 0.16, green: 0.49, blue: 0.32)
}

private enum TimelineSectionID: Hashable {
    case day(Date)
    case missingTime
    case point(UUID)
}

private struct CropMetrics {
    let renderedSize: CGSize
    let overflowX: CGFloat
    let overflowY: CGFloat

    init(imageSize: CGSize, viewport: CGSize) {
        let scale = max(viewport.width / max(imageSize.width, 1),
                        viewport.height / max(imageSize.height, 1))
        renderedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        overflowX = max(0, renderedSize.width - viewport.width)
        overflowY = max(0, renderedSize.height - viewport.height)
    }

    func offset(x: Double, y: Double) -> CGSize {
        CGSize(width: (0.5 - CGFloat(min(max(x, 0), 1))) * overflowX,
               height: (0.5 - CGFloat(min(max(y, 0), 1))) * overflowY)
    }
}

private struct FramedPhoto: View {
    let image: UIImage
    let x: Double
    let y: Double

    var body: some View {
        GeometryReader { proxy in
            let metrics = CropMetrics(imageSize: image.size, viewport: proxy.size)
            let shift = metrics.offset(x: x, y: y)
            Image(uiImage: image)
                .resizable()
                .frame(width: metrics.renderedSize.width, height: metrics.renderedSize.height)
                .position(x: proxy.size.width / 2 + shift.width,
                          y: proxy.size.height / 2 + shift.height)
        }
        .clipped()
    }
}

private struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct ContentView: View {
    @EnvironmentObject private var store: TripStore
    @State private var showingNewTrip = false
    @State private var newTitle = ""
    @State private var alert: AppAlert?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if store.trips.isEmpty { emptyState }
                    else {
                        VStack(spacing: 12) {
                            ForEach(store.trips) { trip in
                                NavigationLink(value: trip.id) {
                                    tripCard(trip)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 36)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationDestination(for: UUID.self) { TripDetailView(tripID: $0) }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewTrip) { newTripSheet }
            .alert(item: $alert) { value in
                Alert(title: Text(value.title), message: Text(value.message),
                      dismissButton: .default(Text("知道了")))
            }
            .onAppear {
                if let error = store.loadError {
                    alert = AppAlert(title: "读取失败", message: error)
                }
            }
        }
        .tint(Palette.blue)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("旅途留影")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Button {
                    newTitle = ""
                    showingNewTrip = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Palette.coral, in: Circle())
                }
                .accessibilityLabel("新建行程")
            }
            Text("从照片出发，记下每一站的时间。")
                .font(.subheadline)
                .foregroundStyle(Palette.ink.opacity(0.64))
            HStack(spacing: 8) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                Text("我的行程")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
            }
            .foregroundStyle(Palette.blue)
            .padding(.top, 10)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Palette.blue)
            Text("先创建一段行程")
                .font(.system(size: 25, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.ink)
            Text("比如“周末去海边”。之后可以一次选入多张照片，时间线会按拍摄时间排好。")
                .font(.body)
                .foregroundStyle(Palette.ink.opacity(0.7))
            Button("创建行程") {
                newTitle = ""
                showingNewTrip = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.coral)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Palette.mist, in: RoundedRectangle(cornerRadius: 22))
    }

    private func tripCard(_ trip: Trip) -> some View {
        HStack(spacing: 16) {
            if let point = trip.points.first {
                thumbnail(for: point)
                    .frame(width: 74, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "map")
                    .font(.title2)
                    .foregroundStyle(Palette.blue)
                    .frame(width: 74, height: 74)
                    .background(Palette.mist, in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(trip.title)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text("\(trip.points.count) 个时间点")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink.opacity(0.6))
                Text(trip.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.blue)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Palette.blue)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.mist, lineWidth: 1))
    }

    private var newTripSheet: some View {
        NavigationStack {
            Form {
                TextField("行程名称，例如：周末去海边", text: $newTitle)
                    .textInputAutocapitalization(.sentences)
            }
            .navigationTitle("新建行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showingNewTrip = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        do {
                            _ = try store.addTrip(title: newTitle)
                            showingNewTrip = false
                        } catch {
                            alert = AppAlert(title: "无法创建行程", message: error.localizedDescription)
                        }
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func thumbnail(for point: PhotoPoint) -> some View {
        Group {
            if let image = UIImage(contentsOfFile: store.thumbnailURL(for: point).path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(Palette.mist)
                    .overlay(Image(systemName: "photo").foregroundStyle(Palette.blue))
            }
        }
        .clipped()
    }
}

private struct TripDetailView: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.openURL) private var openURL
    let tripID: UUID

    @AppStorage("photoTimelineCompactMode") private var compactMode = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var editingPoint: PhotoPoint?
    @State private var showingRename = false
    @State private var renameTitle = ""
    @State private var alert: AppAlert?

    private var trip: Trip? { store.trip(id: tripID) }
    private var sortedPoints: [PhotoPoint] {
        (trip?.points ?? []).sorted { left, right in
            switch (left.capturedAt, right.capturedAt) {
            case let (a?, b?) where a != b: return a < b
            case (_?, nil): return true
            case (nil, _?): return false
            default:
                if left.addedAt != right.addedAt { return left.addedAt < right.addedAt }
                return left.id.uuidString < right.id.uuidString
            }
        }
    }
    private var datedDays: [Date] {
        let calendar = Calendar.current
        return Array(Set(sortedPoints.compactMap { $0.capturedAt.map(calendar.startOfDay(for:)) })).sorted()
    }
    private var hasMissingTimes: Bool { sortedPoints.contains { $0.capturedAt == nil } }
    private static let cardTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                if let trip {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(trip.title)
                                    .font(.system(size: 32, weight: .bold, design: .serif))
                                    .foregroundStyle(Palette.ink)
                                Text("\(trip.points.count) 个时间点 · 按拍摄时间排列")
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.ink.opacity(0.65))
                            }
                            Spacer()
                            Button {
                                renameTitle = trip.title
                                showingRename = true
                            } label: {
                                Image(systemName: "pencil")
                                    .frame(width: 38, height: 38)
                                    .background(Palette.mist, in: Circle())
                            }
                            .accessibilityLabel("修改行程名称")
                        }

                        PhotosPicker(selection: $selectedPhotos, matching: .images,
                                     preferredItemEncoding: .current) {
                            HStack {
                                Image(systemName: "plus")
                                Text(importing ? "正在导入…" : "添加照片")
                                Spacer()
                                Image(systemName: "photo.on.rectangle")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(17)
                            .background(Palette.coral, in: RoundedRectangle(cornerRadius: 16))
                            .contentShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(importing)
                        .zIndex(1)

                        if sortedPoints.isEmpty { emptyTimeline }
                        else {
                            HStack {
                                Spacer()
                                Button {
                                    compactMode.toggle()
                                } label: {
                                    Label(compactMode ? "大图" : "小图",
                                          systemImage: compactMode ? "photo" : "square.grid.2x2")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Palette.blue)
                                        .padding(.horizontal, 14)
                                        .frame(height: 40)
                                        .background(Palette.mist, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(compactMode ? "切换为大图" : "切换为小图")
                            }

                            if compactMode { compactTimeline }
                            else { timeline }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                if !sortedPoints.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            ForEach(datedDays, id: \.self) { day in
                                Button(day.formatted(.dateTime.year().month().day().weekday(.abbreviated))) {
                                    withAnimation { reader.scrollTo(TimelineSectionID.day(day), anchor: .top) }
                                }
                            }
                            if hasMissingTimes {
                                Button("待补录时间") {
                                    withAnimation { reader.scrollTo(TimelineSectionID.missingTime, anchor: .top) }
                                }
                            }
                        } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("跳转日期")
                    }
                }
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotos) { items in
            guard !items.isEmpty else { return }
            importing = true
            Task {
                let result = await store.importPhotos(items, into: tripID)
                selectedPhotos = []
                importing = false
                Task { await store.populateLocations(in: tripID) }
                if result.failed > 0 || result.missingTimes > 0 {
                    var lines = ["已导入 \(result.imported) 张照片。"]
                    if result.missingTimes > 0 { lines.append("\(result.missingTimes) 张没有拍摄时间，请在时间点中补录。") }
                    if result.failed > 0 { lines.append("\(result.failed) 张未能导入，请确认照片已下载到本机后重试。") }
                    alert = AppAlert(title: "导入结果", message: lines.joined(separator: "\n"))
                }
            }
        }
        .sheet(item: $editingPoint) { point in
            PointEditor(tripID: tripID, point: point)
        }
        .sheet(isPresented: $showingRename) { renameSheet }
        .alert(item: $alert) { value in
            Alert(title: Text(value.title), message: Text(value.message),
                  dismissButton: .default(Text("知道了")))
        }
        .task { await store.populateLocations(in: tripID) }
    }

    private var emptyTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(Palette.blue)
            Text("这段行程还没有照片")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text("选入沿途拍的照片，就能看到每一站的拍摄时间和相隔多久。")
                .font(.subheadline)
                .foregroundStyle(Palette.ink.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Palette.mist, in: RoundedRectangle(cornerRadius: 20))
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sortedPoints.enumerated()), id: \.element.id) { index, point in
                if index > 0, let previous = sortedPoints[index - 1].capturedAt,
                   let current = point.capturedAt {
                    let color = intervalColor(current.timeIntervalSince(previous))
                    Text(intervalDescription(from: sortedPoints[index - 1], to: point))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(color)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(alignment: .leading) {
                            Rectangle().fill(color.opacity(0.4))
                                .frame(width: 2, height: 30)
                                .frame(width: 50, height: 38, alignment: .top)
                        }
                } else if index > 0 {
                    Rectangle().fill(Palette.blue.opacity(0.4))
                        .frame(width: 2, height: 20)
                        .frame(width: 50, height: 28, alignment: .top)
                }
                HStack(alignment: .top, spacing: 18) {
                    if startsNewDay(at: index) {
                        dateCircle(for: point)
                    } else {
                        Circle().fill(Palette.blue)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Palette.paper, lineWidth: 3))
                            .frame(width: 50, height: 40)
                    }
                    pointCard(point)
                }
                .id(startsNewDay(at: index) ? sectionID(for: point) : .point(point.id))
                .padding(.top, startsNewDay(at: index) && index > 0 ? 10 : 0)
            }
        }
        .padding(.top, 4)
        .padding(.leading, -4)
        .padding(.trailing, -10)
    }

    private func dateCircle(for point: PhotoPoint) -> some View {
        let color = point.capturedAt == nil ? Palette.coral : Palette.blue
        return VStack(spacing: 2) {
            if let date = point.capturedAt {
                Text(date.formatted(.dateTime.year()))
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                Text(date.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                    .font(.caption.weight(.bold).monospacedDigit())
            } else {
                Text("待补录")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: 68, height: 68)
        .background(color, in: Circle())
        .frame(width: 50, height: 68)
        .accessibilityLabel(point.capturedAt.map {
            $0.formatted(.dateTime.year().month().day().weekday(.wide))
        } ?? "待补录时间")
    }

    private var compactTimeline: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(sortedPoints.enumerated()), id: \.element.id) { index, point in
                if startsNewDay(at: index) {
                    dayDivider(for: point)
                        .padding(.top, index == 0 ? 0 : 10)
                        .id(sectionID(for: point))
                }
                Button { editingPoint = point } label: {
                    HStack(spacing: 12) {
                        pointThumbnail(point)
                            .frame(width: 64, height: 64)
                            .clipped()
                            .contentShape(Rectangle())
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 4) {
                            if let time = point.capturedAt {
                                Text(time.formatted(.dateTime.month().day().hour().minute()))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.blue)
                            } else {
                                Text("补录拍摄时间")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.coral)
                            }
                            Text(point.note.isEmpty ? "添加备注" : point.note)
                                .font(.subheadline)
                                .foregroundStyle(point.note.isEmpty ? Palette.ink.opacity(0.48) : Palette.ink)
                                .lineLimit(1)
                            if let place = displayPlace(for: point) {
                                Label(place, systemImage: "mappin")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.blue)
                                    .lineLimit(1)
                            }
                            if index > 0, let previous = sortedPoints[index - 1].capturedAt,
                               let current = point.capturedAt {
                                Text(intervalDescription(from: sortedPoints[index - 1], to: point))
                                    .font(.caption.weight(.medium).monospacedDigit())
                                    .foregroundStyle(intervalColor(current.timeIntervalSince(previous)))
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.blue.opacity(0.65))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.mist, lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("打开后可修改时间、备注或删除")
            }
        }
    }

    private func startsNewDay(at index: Int) -> Bool {
        guard index > 0 else { return true }
        switch (sortedPoints[index - 1].capturedAt, sortedPoints[index].capturedAt) {
        case let (previous?, current?):
            return !Calendar.current.isDate(previous, inSameDayAs: current)
        case (nil, nil):
            return false
        default:
            return true
        }
    }

    private func sectionID(for point: PhotoPoint) -> TimelineSectionID {
        guard let date = point.capturedAt else { return .missingTime }
        return .day(Calendar.current.startOfDay(for: date))
    }

    private func dayDivider(for point: PhotoPoint) -> some View {
        let color = point.capturedAt == nil ? Palette.coral : Palette.blue
        return HStack(spacing: 9) {
            Image(systemName: point.capturedAt == nil ? "clock.badge.questionmark" : "calendar")
                .font(.caption.weight(.bold))
            if let date = point.capturedAt {
                Text(date.formatted(.dateTime.year().month().day().weekday(.wide)))
                    .font(.subheadline.weight(.bold))
                Spacer(minLength: 4)
                Text("第\(dayNumber(for: date))天")
                    .font(.caption.weight(.bold))
            } else {
                Text("待补录时间")
                    .font(.subheadline.weight(.bold))
                Spacer(minLength: 4)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func dayNumber(for date: Date) -> Int {
        let calendar = Calendar.current
        var days = Set<Date>()
        for point in sortedPoints {
            guard let capturedAt = point.capturedAt, capturedAt <= date else { break }
            days.insert(calendar.startOfDay(for: capturedAt))
        }
        return max(days.count, 1)
    }

    private func intervalColor(_ interval: TimeInterval) -> Color {
        if interval > 2 * 60 * 60 { return Palette.warning }
        if interval < 20 * 60 { return Palette.shortInterval }
        return Palette.blue
    }

    @ViewBuilder
    private func pointThumbnail(_ point: PhotoPoint) -> some View {
        if let image = UIImage(contentsOfFile: store.thumbnailURL(for: point).path) {
            FramedPhoto(image: image, x: point.framingX ?? 0.5, y: point.framingY ?? 0.5)
        } else {
            Rectangle().fill(Palette.mist)
                .overlay(Image(systemName: "photo").foregroundStyle(Palette.blue))
        }
    }

    private func pointCard(_ point: PhotoPoint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { editingPoint = point } label: {
                pointThumbnail(point)
                    .aspectRatio(1.8, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑照片时间点")

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Button { editingPoint = point } label: {
                        Group {
                            if let time = point.capturedAt {
                                Text(Self.cardTimeFormatter.string(from: time))
                                    .foregroundStyle(Palette.blue)
                            } else {
                                Text("缺少拍摄时间 · 点此补录")
                                    .foregroundStyle(Palette.coral)
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(1)

                    if let place = displayPlace(for: point) {
                        Button { openPlaceInMaps(for: point) } label: {
                            Text(place)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.blue)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("在地图中查看\(place)")
                    }
                }
                if !point.note.isEmpty {
                    Button { editingPoint = point } label: {
                        Text(point.note)
                            .font(.title3)
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.mist, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private func openPlaceInMaps(for point: PhotoPoint) {
        var url = URLComponents()
        url.scheme = "https"
        url.host = "maps.apple.com"
        var query = [URLQueryItem(name: "q", value: displayPlace(for: point))]
        if let latitude = point.latitude, let longitude = point.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            if CLLocationCoordinate2DIsValid(coordinate) {
                query.append(URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"))
            }
        }
        url.queryItems = query
        if let destination = url.url { openURL(destination) }
    }

    private var renameSheet: some View {
        NavigationStack {
            Form { TextField("行程名称", text: $renameTitle) }
                .navigationTitle("修改名称")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showingRename = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            do {
                                try store.renameTrip(id: tripID, title: renameTitle)
                                showingRename = false
                            } catch {
                                alert = AppAlert(title: "无法保存", message: error.localizedDescription)
                            }
                        }
                        .disabled(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        .presentationDetents([.medium])
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        var seconds = max(0, Int(interval.rounded()))
        let days = seconds / 86_400
        seconds %= 86_400
        let hours = seconds / 3_600
        seconds %= 3_600
        let minutes = seconds / 60
        seconds %= 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days)天") }
        if hours > 0 { parts.append("\(hours)小时") }
        if minutes > 0 { parts.append("\(minutes)分") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds)秒") }
        return parts.joined(separator: " ")
    }

    private func intervalDescription(from previous: PhotoPoint, to current: PhotoPoint) -> String {
        guard let firstTime = previous.capturedAt, let secondTime = current.capturedAt else { return "" }
        var description = formatInterval(secondTime.timeIntervalSince(firstTime))
        if let distance = distanceBetween(previous, current) {
            let formatted = distance < 1_000 ? "\(Int(distance.rounded())) 米"
                : String(format: "%.1f 公里", distance / 1_000)
            description += " · \(formatted)"
        }
        return description
    }

    private func distanceBetween(_ first: PhotoPoint, _ second: PhotoPoint) -> CLLocationDistance? {
        guard let firstLatitude = first.latitude, let firstLongitude = first.longitude,
              let secondLatitude = second.latitude, let secondLongitude = second.longitude else { return nil }
        let firstCoordinate = CLLocationCoordinate2D(latitude: firstLatitude, longitude: firstLongitude)
        let secondCoordinate = CLLocationCoordinate2D(latitude: secondLatitude, longitude: secondLongitude)
        guard CLLocationCoordinate2DIsValid(firstCoordinate),
              CLLocationCoordinate2DIsValid(secondCoordinate) else { return nil }
        return CLLocation(latitude: firstLatitude, longitude: firstLongitude)
            .distance(from: CLLocation(latitude: secondLatitude, longitude: secondLongitude))
    }

    private func displayPlace(for point: PhotoPoint) -> String? {
        if let name = point.placeName, !name.isEmpty { return name }
        guard let latitude = point.latitude, let longitude = point.longitude else { return nil }
        return String(format: "%.4f, %.4f", latitude, longitude)
    }
}

private struct PointEditor: View {
    @EnvironmentObject private var store: TripStore
    @Environment(\.dismiss) private var dismiss
    let tripID: UUID
    let point: PhotoPoint

    @State private var note: String
    @State private var placeName: String
    @State private var placeEdited = false
    @State private var hasTime: Bool
    @State private var capturedAt: Date
    @State private var framingX: Double
    @State private var framingY: Double
    @State private var dragStartY: Double?
    @State private var showingDeleteConfirmation = false
    @State private var alert: AppAlert?

    init(tripID: UUID, point: PhotoPoint) {
        self.tripID = tripID
        self.point = point
        _note = State(initialValue: point.note)
        _placeName = State(initialValue: point.placeName ?? "")
        _hasTime = State(initialValue: point.capturedAt != nil)
        _framingX = State(initialValue: point.framingX ?? 0.5)
        _framingY = State(initialValue: point.framingY ?? 0.5)
        _capturedAt = State(initialValue: point.capturedAt
            ?? Calendar.current.dateInterval(of: .minute, for: Date())?.start
            ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("照片显示位置") {
                    if let image = UIImage(contentsOfFile: store.thumbnailURL(for: point).path) {
                        GeometryReader { proxy in
                            let metrics = CropMetrics(imageSize: image.size, viewport: proxy.size)
                            FramedPhoto(image: image, x: framingX, y: framingY)
                                .contentShape(Rectangle())
                                .highPriorityGesture(DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let start = dragStartY ?? framingY
                                        if dragStartY == nil { dragStartY = start }
                                        framingY = metrics.overflowY > 0
                                            ? min(max(start - Double(value.translation.height / metrics.overflowY), 0), 1)
                                            : 0.5
                                    }
                                    .onEnded { _ in dragStartY = nil })
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("上下拖动调整照片在卡片中的位置")
                        Text("上下拖动照片调整显示位置")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("原图不会修改")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("恢复垂直居中") { framingY = 0.5 }
                            .font(.footnote)
                        }
                    }
                }
                Section("拍摄时间") {
                    Toggle("使用时间", isOn: $hasTime)
                    if hasTime {
                        DatePicker("日期和时间", selection: $capturedAt,
                                   displayedComponents: [.date, .hourAndMinute])
                    } else {
                        Text("没有拍摄时间的照片会排在时间线末尾。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("地点或备注") {
                    TextField("拍摄地点", text: $placeName)
                        .onChange(of: placeName) { _ in placeEdited = true }
                    if let latitude = point.latitude, let longitude = point.longitude {
                        Text(String(format: "GPS：%.4f, %.4f", latitude, longitude))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    TextField("例如：到达海边，看了日落", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    Button("从行程删除这张照片", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("编辑时间点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do {
                            let chosenTime: Date?
                            if hasTime {
                                chosenTime = capturedAt == point.capturedAt ? capturedAt
                                    : (Calendar.current.dateInterval(of: .minute, for: capturedAt)?.start ?? capturedAt)
                            } else {
                                chosenTime = nil
                            }
                            try store.updatePoint(tripID: tripID, pointID: point.id,
                                                  capturedAt: chosenTime, note: note,
                                                  framingX: framingX, framingY: framingY,
                                                  placeName: placeEdited ? placeName : nil)
                            dismiss()
                        } catch {
                            alert = AppAlert(title: "无法保存", message: error.localizedDescription)
                        }
                    }
                }
            }
            .alert(item: $alert) { value in
                Alert(title: Text(value.title), message: Text(value.message),
                      dismissButton: .default(Text("知道了")))
            }
            .confirmationDialog("删除这个时间点？", isPresented: $showingDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("删除照片", role: .destructive) {
                    do {
                        try store.deletePoint(tripID: tripID, pointID: point.id)
                        dismiss()
                    } catch {
                        alert = AppAlert(title: "无法删除", message: error.localizedDescription)
                    }
                }
            } message: {
                Text("只删除这段行程中的时间点和 App 内的照片副本，系统相册中的原图不会删除。")
            }
        }
    }
}
