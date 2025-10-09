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

    @State private var tab = 0
    let tabTitles = ["Forecast", "Variance", "Trends"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AVR Entertainment").font(.title3).bold().padding()
                Spacer()
            }
            Text("PREDICTIVE ANALYSIS")
                .font(.title2).bold().foregroundColor(.purple)
                .padding(.bottom, 10)
            
            // Tabs
            HStack {
                ForEach(0..<tabTitles.count, id: \.self) { idx in
                    Button(action: { tab = idx }) {
                        Text(tabTitles[idx])
                            .bold(tab == idx)
                            .foregroundColor(tab == idx ? .blue : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(tab == idx ? Color.blue.opacity(0.15) : .clear)
                            .clipShape(Capsule())
                    }
                }
            }.padding(.vertical, 6)
            
            if vm.isLoading {
                VStack {
                    ProgressView("Loading analytics...")
                        .frame(height: 200)
                }
            } else {
                TabView(selection: $tab) {
                    linechart.tag(0)
                    varianceTab.tag(1)
                    trendsTab.tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 340)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Summary")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.summaryText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await vm.fetchData()
        }
    }
            
    var linechart: some View {
        VStack(alignment: .leading) {
            
            if vm.customMonthlyData == []{
                Text("No data is available")
            }else{
                
                Chart {
                    // Budget Line (Blue)
                    ForEach(vm.customMonthlyData) { item in
                        LineMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.budget),
                            series: .value("Type", "Budget")
                        )
                        .foregroundStyle(.blue)
                    }
                    
                    // Actual Line (Purple)
                    ForEach(vm.customMonthlyData) { item in
                        if let actualPoint = item.actual{
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Amount", actualPoint),
                                series: .value("Type", "Actual")
                            )
                            .foregroundStyle(.purple)
                        }
                    }
                    
                    // Forecast Line (Green)
                    ForEach(vm.customMonthlyData) { item in
                        if let ForecastPoint = item.forecast{
                            LineMark(
                                x: .value("Month", item.month),
                                y: .value("Amount", ForecastPoint),
                                series: .value("Type", "Forecast")
                            )
                            .foregroundStyle(.green)
                        }
                    }
                }
                .frame(height: 300)
                .chartYAxisLabel("Amount", position: .leading)
                .chartXAxisLabel("Months")
                .chartForegroundStyleScale([
                    "Budget": .blue,
                    "Forecast": .green,
                    "Actual": .purple
                ])
                .chartLegend(position: .bottom)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .shadow(radius: 4)
            }
        }
        .padding()
    }

    var varianceTab: some View {
        VStack {
            Text("Variance Analysis").font(.headline).foregroundColor(.purple)
            if vm.months.isEmpty {
                Text("No data available")
                    .foregroundColor(.gray)
                    .frame(height: 180)
            } else {
                Chart {
                    ForEach(Array(vm.months.enumerated()), id: \.0) { i, m in
                        // Budget Bar
                        BarMark(
                            x: .value("Month", m),
                            y: .value("Budget", vm.perMonthBudget[i])
                        )
                        .foregroundStyle(.blue)
                        .position(by: .value("Type", "Budget"))
                        
                        // Actual Bar
                        BarMark(
                            x: .value("Month", m),
                            y: .value("Actual", vm.actuals[i])
                        )
                        .foregroundStyle(.purple)
                        .position(by: .value("Type", "Actual"))
                        
                        // Forecast Bar
                        BarMark(
                            x: .value("Month", m),
                            y: .value("Forecast", vm.forecast[i])
                        )
                        .foregroundStyle(.green)
                        .position(by: .value("Type", "Forecast"))
                    }
                }
                .frame(height: 180)
                .padding(.horizontal, 6)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Double.self) {
                                Text("\(Int(intValue))")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisValueLabel {
                            if let stringValue = value.as(String.self) {
                                Text(stringValue)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(Color.white)
                }
            }
            legendBox
        }
    }
    
    var trendsTab: some View {
        VStack {
            Text("Trends Analysis").font(.headline).foregroundColor(.purple)
            if vm.trends.isEmpty {
                Text("No data available")
                    .foregroundColor(.gray)
                    .frame(height: 180)
            } else {
                GeometryReader { geometry in
                    PieChartView(data: vm.trends)
                        .frame(width: geometry.size.width * 0.82, height: 160)
                }
                HStack(spacing: 10) {
                    ForEach(vm.trends, id: \.category) { t in
                        RoundedRectangle(cornerRadius: 2).fill(colorForCategory(t.category)).frame(width: 22, height: 8)
                        Text(t.category)
                    }
                }.font(.caption)
            }
        }
    }
    
    var legendBox: some View {
        HStack(spacing: 10) {
            Color.blue.frame(width: 22, height: 8).cornerRadius(3)
            Text("Budget")
            Color.purple.frame(width: 22, height: 8).cornerRadius(3)
            Text("Actual")
            Color.green.frame(width: 22, height: 8).cornerRadius(3)
            Text("Forecast")
        }.font(.caption)
    }
    
    func colorForCategory(_ cat: String) -> Color {
        switch cat {
        case "Travel": return .blue
        case "Meals": return .purple
        case "Misc": return .green
        default: return .gray
        }
    }
}


struct PieChartView: View {
    let data: [(category: String, percent: Double)]
    var total: Double { data.reduce(0) { $0 + $1.percent } }
    var colors: [Color] = [.blue, .purple, .green, .orange, .red, .gray, .mint, .teal]
    
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
