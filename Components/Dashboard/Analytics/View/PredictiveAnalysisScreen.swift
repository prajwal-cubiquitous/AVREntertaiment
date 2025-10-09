//
//  PredictiveAnalysisScreen.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/8/25.
//

import SwiftUI
import Charts

struct PredictiveAnalysisScreen: View {
   
    let project: Project
    @StateObject private var vm: PredictiveAnalysisViewModel

    init(project: Project) {
        self.project = project
        _vm = StateObject(wrappedValue: PredictiveAnalysisViewModel(project: project))
    }

    @State private var selectedTab = 0
    @State private var showingDetailView = false
    
    // Chart interaction states
    @State private var selectedForecastItem: MonthlyData?
    @State private var selectedVarianceItem: (month: String, budget: Double, actual: Double?, forecast: Double?)?
    @State private var selectedTrendItem: (category: String, percent: Double)?
    @State private var showingChartDetail = false
    
    private let tabTitles = ["Forecast", "Variance", "Trends"]
    private let tabIcons = ["chart.line.uptrend.xyaxis", "chart.bar.fill", "chart.pie.fill"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Tab Selection
                    tabSelectionView
                    
                    // Content Section
                    if vm.isLoading {
                        loadingView
                    } else {
                        contentView
                    }
                    
                    // Summary Section
                    summarySection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .task {
            await vm.fetchData()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AVR Entertainment")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Predictive Analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button(action: { showingDetailView = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            
            // Project Info Card
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Project Budget")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("₹\(String(format: "%.0f", project.budget))")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(vm.monthlyData.count) months")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Tab Selection
    private var tabSelectionView: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabTitles.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: tabIcons[index])
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(selectedTab == index ? .white : .blue)
                        
                        Text(tabTitles[index])
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == index ? .white : .blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTab == index ? Color.blue : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Content View
    private var contentView: some View {
        VStack(spacing: 0) {
            switch selectedTab {
            case 0:
                forecastView
            case 1:
                varianceView
            case 2:
                trendsView
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading analytics...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Summary Section
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Financial Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {}) {
                    Text("View Details")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text(vm.summaryText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Forecast View
    private var forecastView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if vm.customMonthlyData.isEmpty {
                emptyStateView(title: "No Forecast Data", message: "Unable to generate forecast data for this project")
            } else {
                Chart {
                    // Budget Line (Blue)
                    ForEach(vm.customMonthlyData) { item in
                        LineMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.budget),
                            series: .value("Type", "Budget")
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .symbol(.circle)
                        .symbolSize(40)
                        .opacity(selectedForecastItem?.month == item.month ? 1.0 : 0.7)
                    }
                    
                    // Actual Line (Purple)
                    ForEach(vm.customMonthlyData) { item in
                        if let actualPoint = item.actual {
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Amount", actualPoint),
                                series: .value("Type", "Actual")
                            )
                            .foregroundStyle(.purple)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .symbol(.circle)
                            .symbolSize(40)
                            .opacity(selectedForecastItem?.month == item.month ? 1.0 : 0.7)
                        }
                    }
                    
                    // Forecast Line (Green)
                    ForEach(vm.customMonthlyData) { item in
                        if let forecastPoint = item.forecast {
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Amount", forecastPoint),
                                series: .value("Type", "Forecast")
                            )
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 3, dash: [8, 4]))
                            .symbol(.diamond)
                            .symbolSize(40)
                            .opacity(selectedForecastItem?.month == item.month ? 1.0 : 0.7)
                        }
                    }
                }
                .onTapGesture { location in
                    // Calculate which month was clicked based on tap location
                    let chartWidth = UIScreen.main.bounds.width - 32 // Account for padding
                    let dataCount = vm.customMonthlyData.count
                    
                    // Calculate the index based on tap position
                    let index = Int((location.x / chartWidth) * Double(dataCount))
                    
                    if index >= 0 && index < vm.customMonthlyData.count {
                        selectedForecastItem = vm.customMonthlyData[index]
                        showingChartDetail = true
                    }
                }
                .frame(height: 280)
                .chartYAxisLabel("Amount (₹)", position: .leading)
                .chartXAxisLabel("Months")
                .chartForegroundStyleScale([
                    "Budget": .blue,
                    "Forecast": .green,
                    "Actual": .purple
                ])
                .chartLegend(position: .bottom, alignment: .center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                
                // Selected item details
                if let selectedItem = selectedForecastItem {
                    forecastDetailCard(item: selectedItem)
                }
            }
        }
    }
    
    // MARK: - Variance View (Enhanced with fetchExpenses data)
    private var varianceView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if vm.customMonthlyData.isEmpty {
                emptyStateView(title: "No Variance Data", message: "Unable to calculate variance for this project")
            } else {
                // Key Metrics Cards
                HStack(spacing: 12) {
                    metricCard(
                        title: "Total Spent",
                        value: "₹\(String(format: "%.0f", vm.customMonthlyData.compactMap { $0.actual }.reduce(0, +)))",
                        color: .purple
                    )
                    
                    metricCard(
                        title: "Remaining",
                        value: "₹\(String(format: "%.0f", project.budget - vm.customMonthlyData.compactMap { $0.actual }.reduce(0, +)))",
                        color: .green
                    )
                }
                
                // Variance Chart
                Chart {
                    ForEach(vm.customMonthlyData) { item in
                        // Budget Bar
                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Budget", item.budget)
                        )
                        .foregroundStyle(.blue)
                        .position(by: .value("Type", "Budget"))
                        .opacity(selectedVarianceItem?.month == item.month ? 1.0 : 0.7)
                        
                        // Actual Bar
                        if let actual = item.actual {
                            BarMark(
                                x: .value("Month", item.month),
                                y: .value("Actual", actual)
                            )
                            .foregroundStyle(.purple)
                            .position(by: .value("Type", "Actual"))
                            .opacity(selectedVarianceItem?.month == item.month ? 1.0 : 0.7)
                        }
                        
                        // Forecast Bar
                        if let forecast = item.forecast {
                            BarMark(
                                x: .value("Month", item.month),
                                y: .value("Forecast", forecast)
                            )
                            .foregroundStyle(.green)
                            .position(by: .value("Type", "Forecast"))
                            .opacity(selectedVarianceItem?.month == item.month ? 1.0 : 0.7)
                        }
                    }
                }
                .onTapGesture { location in
                    // Calculate which month was clicked based on tap location
                    let chartWidth = UIScreen.main.bounds.width - 32 // Account for padding
                    let dataCount = vm.customMonthlyData.count
                    
                    // Calculate the index based on tap position
                    let index = Int((location.x / chartWidth) * Double(dataCount))
                    
                    if index >= 0 && index < vm.customMonthlyData.count {
                        let item = vm.customMonthlyData[index]
                        selectedVarianceItem = (
                            month: item.month,
                            budget: item.budget,
                            actual: item.actual,
                            forecast: item.forecast
                        )
                        showingChartDetail = true
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Double.self) {
                                Text("₹\(Int(intValue))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisValueLabel {
                            if let stringValue = value.as(String.self) {
                                Text(stringValue)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(Color(.systemGray6))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                
                // Selected item details
                if let selectedItem = selectedVarianceItem {
                    varianceDetailCard(item: selectedItem)
                }
                
                // Legend
                legendView
            }
        }
    }
    
    // MARK: - Trends View
    private var trendsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if vm.trends.isEmpty {
                emptyStateView(title: "No Trends Data", message: "Unable to generate spending trends for this project")
            } else {
                GeometryReader { geometry in
                    HStack {
                        Spacer()
                        InteractivePieChartView(
                            data: vm.trends,
                            selectedItem: $selectedTrendItem,
                            showingDetail: $showingChartDetail
                        )
                        .frame(width: min(geometry.size.width * 0.8, 200), height: 200)
                        Spacer()
                    }
                }
                .frame(height: 200)
                
                // Category Legend with tap gestures
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(vm.trends, id: \.category) { trend in
                        Button(action: {
                            selectedTrendItem = trend
                            showingChartDetail = true
                        }) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorForCategory(trend.category))
                                    .frame(width: 16, height: 16)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trend.category)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(String(format: "%.1f", trend.percent))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedTrendItem?.category == trend.category {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTrendItem?.category == trend.category ? 
                                          Color.blue.opacity(0.1) : Color(.systemGray6))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                
                // Selected item details
                if let selectedItem = selectedTrendItem {
                    trendDetailCard(item: selectedItem)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
    
    private func emptyStateView(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private var legendView: some View {
        HStack(spacing: 16) {
            ForEach([("Budget", Color.blue), ("Actual", Color.purple), ("Forecast", Color.green)], id: \.0) { item in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(item.1)
                        .frame(width: 12, height: 12)
                    
                    Text(item.0)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Detail Cards
    private func forecastDetailCard(item: MonthlyData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(item.month) Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { selectedForecastItem = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Budget:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("₹\(String(format: "%.0f", item.budget))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                if let actual = item.actual {
                    HStack {
                        Text("Actual:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("₹\(String(format: "%.0f", actual))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }
                    
                    let variance = actual - item.budget
                    let variancePercent = item.budget > 0 ? (variance / item.budget) * 100 : 0
                    
                    HStack {
                        Text("Variance:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(variance >= 0 ? "+" : "")₹\(String(format: "%.0f", variance)) (\(String(format: "%.1f", variancePercent))%)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(variance >= 0 ? .red : .green)
                    }
                }
                
                if let forecast = item.forecast {
                    HStack {
                        Text("Forecast:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("₹\(String(format: "%.0f", forecast))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func varianceDetailCard(item: (month: String, budget: Double, actual: Double?, forecast: Double?)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(item.month) Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { selectedVarianceItem = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Budget:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("₹\(String(format: "%.0f", item.budget))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                if let actual = item.actual {
                    HStack {
                        Text("Actual:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("₹\(String(format: "%.0f", actual))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }
                    
                    let variance = actual - item.budget
                    let variancePercent = item.budget > 0 ? (variance / item.budget) * 100 : 0
                    
                    HStack {
                        Text("Variance:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(variance >= 0 ? "+" : "")₹\(String(format: "%.0f", variance)) (\(String(format: "%.1f", variancePercent))%)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(variance >= 0 ? .red : .green)
                    }
                }
                
                if let forecast = item.forecast {
                    HStack {
                        Text("Forecast:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("₹\(String(format: "%.0f", forecast))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func trendDetailCard(item: (category: String, percent: Double)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(item.category) Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { selectedTrendItem = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Category:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(item.category)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text("Percentage:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", item.percent))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                let totalSpent = vm.customMonthlyData.compactMap { $0.actual }.reduce(0, +)
                let categoryAmount = (item.percent / 100) * totalSpent
                
                HStack {
                    Text("Amount:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("₹\(String(format: "%.0f", categoryAmount))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    func colorForCategory(_ cat: String) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .red, .mint, .teal, .indigo, .pink, .brown]
        let hash = cat.hashValue
        return colors[abs(hash) % colors.count]
    }
}


struct PieChartView: View {
    let data: [(category: String, percent: Double)]
    var total: Double { data.reduce(0) { $0 + $1.percent } }
    var colors: [Color] = [.blue, .purple, .green, .orange, .red, .mint, .teal, .indigo, .pink, .brown]
    
    struct Slice {
        let startAngle: Angle
        let endAngle: Angle
        let color: Color
        let label: String
        let percentValue: Double
    }
    
    var slices: [Slice] {
        var result: [Slice] = []
        var currentAngle = Angle(degrees: 0)
        for (i, d) in data.enumerated() {
            let percent = d.percent / total
            let angle = Angle(degrees: percent * 360)
            let slice = Slice(
                startAngle: currentAngle,
                endAngle: currentAngle + angle,
                color: colors[i % colors.count],
                label: d.category,
                percentValue: d.percent
            )
            result.append(slice)
            currentAngle += angle
        }
        return result
    }
    
    var body: some View {
        GeometryReader { g in
            let size = min(g.size.width, g.size.height)
            let radius = size / 2
            let center = CGPoint(x: size/2, y: size/2)
            ZStack {
                ForEach(Array(slices.enumerated()), id: \.offset) { i, slice in
                    PieSlice(start: slice.startAngle, end: slice.endAngle, color: slice.color)
                    PieLabel(center: center, radius: radius, start: slice.startAngle, angle: slice.endAngle - slice.startAngle, label: "\(slice.label)\n\(Int(slice.percentValue))%")
                }
            }
        }
    }
}


struct PieSlice: View {
    let start: Angle
    let end: Angle
    let color: Color
    var body: some View {
        GeometryReader { g in
            let size = min(g.size.width, g.size.height)
            Path { path in
                path.move(to: CGPoint(x: size/2, y: size/2))
                path.addArc(center: CGPoint(x: size/2, y: size/2), radius: size/2, startAngle: start, endAngle: end, clockwise: false)
            }
            .fill(color)
        }
    }
}

struct PieLabel: View {
    let center: CGPoint
    let radius: CGFloat
    let start: Angle
    let angle: Angle
    let label: String
    var body: some View {
        let midAngle = Angle(degrees: start.degrees + angle.degrees/2)
        let labelRadius = radius * 0.65
        let x = center.x + labelRadius * CGFloat(cos(midAngle.radians))
        let y = center.y + labelRadius * CGFloat(sin(midAngle.radians))
        return Text(label)
            .font(.caption2)
            .position(x: x, y: y)
    }
}

// MARK: - Interactive Pie Chart View
struct InteractivePieChartView: View {
    let data: [(category: String, percent: Double)]
    @Binding var selectedItem: (category: String, percent: Double)?
    @Binding var showingDetail: Bool
    
    var total: Double { data.reduce(0) { $0 + $1.percent } }
    var colors: [Color] = [.blue, .purple, .green, .orange, .red, .mint, .teal, .indigo, .pink, .brown]
    
    struct Slice {
        let startAngle: Angle
        let endAngle: Angle
        let color: Color
        let label: String
        let percentValue: Double
        let category: String
    }
    
    var slices: [Slice] {
        var result: [Slice] = []
        var currentAngle = Angle(degrees: 0)
        for (i, d) in data.enumerated() {
            let percent = d.percent / total
            let angle = Angle(degrees: percent * 360)
            let slice = Slice(
                startAngle: currentAngle,
                endAngle: currentAngle + angle,
                color: colors[i % colors.count],
                label: d.category,
                percentValue: d.percent,
                category: d.category
            )
            result.append(slice)
            currentAngle += angle
        }
        return result
    }
    
    var body: some View {
        GeometryReader { g in
            let size = min(g.size.width, g.size.height)
            let radius = size / 2
            let center = CGPoint(x: size/2, y: size/2)
            ZStack {
                ForEach(Array(slices.enumerated()), id: \.offset) { i, slice in
                    InteractivePieSlice(
                        start: slice.startAngle,
                        end: slice.endAngle,
                        color: slice.color,
                        isSelected: selectedItem?.category == slice.category
                    )
                    .onTapGesture {
                        selectedItem = (category: slice.category, percent: slice.percentValue)
                        showingDetail = true
                    }
                    
                    InteractivePieLabel(
                        center: center,
                        radius: radius,
                        start: slice.startAngle,
                        angle: slice.endAngle - slice.startAngle,
                        label: "\(slice.label)\n\(Int(slice.percentValue))%",
                        isSelected: selectedItem?.category == slice.category
                    )
                }
            }
        }
    }
}

struct InteractivePieSlice: View {
    let start: Angle
    let end: Angle
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        GeometryReader { g in
            let size = min(g.size.width, g.size.height)
            Path { path in
                path.move(to: CGPoint(x: size/2, y: size/2))
                path.addArc(center: CGPoint(x: size/2, y: size/2), radius: size/2, startAngle: start, endAngle: end, clockwise: false)
            }
            .fill(color)
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
    }
}

struct InteractivePieLabel: View {
    let center: CGPoint
    let radius: CGFloat
    let start: Angle
    let angle: Angle
    let label: String
    let isSelected: Bool
    
    var body: some View {
        let midAngle = Angle(degrees: start.degrees + angle.degrees/2)
        let labelRadius = radius * (isSelected ? 0.75 : 0.65)
        let x = center.x + labelRadius * CGFloat(cos(midAngle.radians))
        let y = center.y + labelRadius * CGFloat(sin(midAngle.radians))
        return Text(label)
            .font(.caption2)
            .fontWeight(isSelected ? .bold : .regular)
            .foregroundColor(isSelected ? .white : .primary)
            .position(x: x, y: y)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
