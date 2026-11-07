import SwiftUI
import AppKit

/// A custom date/time picker: a styled month calendar plus iOS-style time wheels.
struct DateTimePicker: View {
  @Binding var selection: Date

  var body: some View {
    VStack(spacing: 10) {
      CalendarView(selection: $selection)
      TimeWheelSection(selection: $selection)
    }
  }
}

// MARK: - Calendar

private struct CalendarView: View {
  @Binding var selection: Date

  @State private var displayedMonth: Date
  @State private var hoveredDay: Date?

  private let calendar = Calendar.current
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

  private static let monthFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
    return formatter
  }()

  init(selection: Binding<Date>) {
    _selection = selection
    let calendar = Calendar.current
    let start = calendar.date(
      from: calendar.dateComponents([.year, .month], from: selection.wrappedValue)
    ) ?? selection.wrappedValue
    _displayedMonth = State(initialValue: start)
  }

  var body: some View {
    VStack(spacing: 8) {
      header
      weekdayHeader
      daysGrid
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    )
    .onChange(of: selection) { _, newValue in
      let month = startOfMonth(newValue)
      if !calendar.isDate(month, equalTo: displayedMonth, toGranularity: .month) {
        displayedMonth = month
      }
    }
  }

  // MARK: Header

  private var header: some View {
    HStack(spacing: 8) {
      monthButton(systemImage: "chevron.left") {
        shiftMonth(by: -1)
      }

      Spacer()

      Text(Self.monthFormatter.string(from: displayedMonth))
        .font(.system(.headline, design: .rounded))
        .monospacedDigit()

      Spacer()

      monthButton(systemImage: "chevron.right") {
        shiftMonth(by: 1)
      }
    }
  }

  private func monthButton(systemImage: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 24, height: 24)
        .background(Circle().fill(Color.primary.opacity(0.06)))
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
  }

  // MARK: Grid

  private var weekdayHeader: some View {
    LazyVGrid(columns: columns, spacing: 0) {
      ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { item in
        Text(item.element.uppercased())
          .font(.system(size: 10, weight: .semibold, design: .rounded))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .frame(height: 16)
      }
    }
  }

  private var daysGrid: some View {
    LazyVGrid(columns: columns, spacing: 2) {
      ForEach(days, id: \.self) { day in
        dayCell(day)
      }
    }
  }

  private func dayCell(_ day: Date) -> some View {
    let inMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
    let isSelected = calendar.isDate(day, inSameDayAs: selection)
    let isToday = calendar.isDateInToday(day)
    let isHovered = hoveredDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
    let dayNumber = calendar.component(.day, from: day)

    return Button {
      select(day)
    } label: {
      Text("\(dayNumber)")
        .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
        .foregroundStyle(dayColor(isSelected: isSelected, inMonth: inMonth, isToday: isToday))
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background {
          if isSelected {
            Circle()
              .fill(
                LinearGradient(
                  colors: [.accentColor, .accentColor.opacity(0.78)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .frame(width: 28, height: 28)
              .shadow(color: .accentColor.opacity(0.35), radius: 3, y: 1)
          } else if isHovered {
            Circle()
              .fill(Color.primary.opacity(0.07))
              .frame(width: 28, height: 28)
          } else if isToday {
            Circle()
              .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1)
              .frame(width: 28, height: 28)
          }
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      if hovering {
        hoveredDay = day
      } else if hoveredDay.map({ calendar.isDate($0, inSameDayAs: day) }) == true {
        hoveredDay = nil
      }
    }
  }

  private func dayColor(isSelected: Bool, inMonth: Bool, isToday: Bool) -> Color {
    if isSelected { return .white }
    if isToday { return .accentColor }
    if !inMonth { return .secondary.opacity(0.45) }
    return .primary
  }

  // MARK: Helpers

  private var orderedWeekdaySymbols: [String] {
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    let firstIndex = calendar.firstWeekday - 1
    guard firstIndex > 0 else { return symbols }
    return Array(symbols[firstIndex...] + symbols[..<firstIndex])
  }

  private var days: [Date] {
    let monthStart = startOfMonth(displayedMonth)
    let weekday = calendar.component(.weekday, from: monthStart)
    let offset = (weekday - calendar.firstWeekday + 7) % 7
    guard let gridStart = calendar.date(byAdding: .day, value: -offset, to: monthStart) else {
      return []
    }
    let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    let rows = Int(ceil(Double(offset + dayCount) / 7.0))
    return (0..<(rows * 7)).compactMap {
      calendar.date(byAdding: .day, value: $0, to: gridStart)
    }
  }

  private func startOfMonth(_ date: Date) -> Date {
    calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
  }

  private func shiftMonth(by value: Int) {
    guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
      return
    }
    displayedMonth = startOfMonth(newMonth)
  }

  private func select(_ day: Date) {
    let time = calendar.dateComponents([.hour, .minute], from: selection)
    var components = calendar.dateComponents([.year, .month, .day], from: day)
    components.hour = time.hour
    components.minute = time.minute
    components.second = 0

    guard let newSelection = calendar.date(from: components) else { return }
    selection = newSelection

    if !calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
      displayedMonth = startOfMonth(day)
    }
  }
}

// MARK: - Time wheels

private struct TimeWheelSection: View {
  @Binding var selection: Date

  var body: some View {
    HStack(spacing: 12) {
      WheelPicker(values: Array(0...23), selection: hourBinding)
        .accessibilityLabel("Hour")
      Text(":")
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
        .offset(y: -1)
      WheelPicker(values: Array(0...59), selection: minuteBinding)
        .accessibilityLabel("Minute")
    }
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.primary.opacity(0.035))
    )
  }

  private var hourBinding: Binding<Int> {
    Binding(
      get: { Calendar.current.component(.hour, from: selection) },
      set: { newHour in
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: selection)
        if let date = calendar.date(bySettingHour: newHour, minute: minute, second: 0, of: selection) {
          selection = date
        }
      }
    )
  }

  private var minuteBinding: Binding<Int> {
    Binding(
      get: { Calendar.current.component(.minute, from: selection) },
      set: { newMinute in
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: selection)
        if let date = calendar.date(bySettingHour: hour, minute: newMinute, second: 0, of: selection) {
          selection = date
        }
      }
    )
  }
}

/// A scrollable, snapping wheel that mimics the iOS picker.
private struct WheelPicker: View {
  let values: [Int]
  @Binding var selection: Int

  private let rowHeight: CGFloat = 28
  private let visibleRows: CGFloat = 3

  @State private var scrolledID: Int?

  private var height: CGFloat { rowHeight * visibleRows }

  init(values: [Int], selection: Binding<Int>) {
    self.values = values
    self._selection = selection
    self._scrolledID = State(initialValue: selection.wrappedValue)
  }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.primary.opacity(0.07))
        .frame(height: rowHeight)

      ScrollView(.vertical) {
        LazyVStack(spacing: 0) {
          ForEach(values, id: \.self) { value in
            Text(String(format: "%02d", value))
              .font(.system(size: 19, weight: .medium, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(value == selection ? Color.primary : Color.secondary.opacity(0.7))
              .frame(height: rowHeight)
              .frame(maxWidth: .infinity)
          }
        }
        .scrollTargetLayout()
      }
      .frame(height: height)
      .scrollIndicators(.hidden)
      .scrollTargetBehavior(.viewAligned)
      .scrollPosition(id: $scrolledID, anchor: .center)
      .contentMargins(.vertical, (height - rowHeight) / 2, for: .scrollContent)
      .mask(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0),
            .init(color: .black, location: 0.22),
            .init(color: .black, location: 0.78),
            .init(color: .clear, location: 1)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
    }
    .frame(width: 64, height: height)
    .onAppear {
      scrolledID = selection
    }
    .onChange(of: scrolledID) { _, newValue in
      guard let newValue, newValue != selection else { return }
      selection = newValue
    }
    .onChange(of: selection) { _, newValue in
      guard scrolledID != newValue else { return }
      withAnimation(.easeInOut(duration: 0.2)) {
        scrolledID = newValue
      }
    }
  }
}
