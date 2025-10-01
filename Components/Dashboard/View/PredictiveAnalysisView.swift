import SwiftUI
import Charts

struct PredictiveAnalysisView: View {
    let project: Project
    @State private var selectedTab = 0
    @State private var analysisResults: AnalysisResults?
    @State private var isLoading = true
    
    private let tabs = ["Forecast", "Variance", "Trends"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Segmented Control
                segmentedControl
                
                // Content Area
                contentArea
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            loadAllData()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            // Status bar spacer
            Rectangle()
                .fill(Color.clear)
                .frame(height: 1)
            
            HStack(spacing: 16) {
                // Menu button
                Button(action: {}) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.2))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Title
                VStack(spacing: 2) {
                    Text("Predictive Analysis")
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                    
                    Text("Budget Insights & Forecasting")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Placeholder for symmetry
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.545, green: 0.373, blue: 0.749),
                    Color(red: 0.545, green: 0.373, blue: 0.749).opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Segmented Control
    private var segmentedControl: some View {
        HStack(spacing: 8) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = index
                    }
                }) {
                    Text(tabs[index])
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedTab == index ? .white : Color(.systemGray))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == index ? 
                                      Color(red: 0.545, green: 0.373, blue: 0.749) : 
                                      Color(.systemGray6))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Content Area
    private var contentArea: some View {
        VStack {
            if isLoading {
                loadingView
            } else if let results = analysisResults {
                switch selectedTab {
                case 0:
                    ForecastTabView(data: results.forecastData)
                case 1:
                    VarianceTabView(data: results.varianceData)
                case 2:
                    TrendsTabView(data: results.trendsData)
                default:
                    EmptyView()
                }
            } else {
                emptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Loading animation
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.545, green: 0.373, blue: 0.749),
                                Color(red: 0.545, green: 0.373, blue: 0.749).opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
            }
            
            VStack(spacing: 8) {
                Text("Analyzing Data")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Generating insights and forecasts...")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Empty state icon
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                Text("No Analysis Data")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Unable to generate analysis with current project data")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Data Loading
    private func loadAllData() {
        guard let _ = project.id else { return }
        
        isLoading = true
        
        // Generate report data from project
        let reportData = generateReportData(from: project)
        
        // Use AnalysisManager to generate analysis results
        let analysisManager = AnalysisManager()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let forecastData = analysisManager.generateForecastData(from: reportData)
            let varianceData = analysisManager.generateVarianceData(from: reportData)
            let trendsData = analysisManager.generateTrendsData(from: reportData)
            
            self.analysisResults = AnalysisResults(
                forecastData: forecastData,
                varianceData: varianceData,
                trendsData: trendsData,
                totalSpent: reportData.totalSpent,
                totalBudget: reportData.totalBudget,
                budgetUsagePercentage: reportData.budgetUsagePercentage
            )
            
            self.isLoading = false
        }
    }
    
    // MARK: - Helper Methods
    private func generateReportData(from project: Project) -> ReportData {
        // Calculate total spent from project data
        let totalSpent = project.departments.values.reduce(0, +) // Using department budgets as spent for demo
        let totalBudget = project.budget
        let budgetUsagePercentage = totalBudget > 0 ? (totalSpent / totalBudget) * 100 : 0
        
        // Generate expenses by department
        let expensesByDepartment = project.departments
        
        // Generate sample expenses by category
        let expensesByCategory: [String: Double] = [
            "Travel": totalSpent * 0.35,
            "Meals": totalSpent * 0.25,
            "Equipment": totalSpent * 0.20,
            "Miscellaneous": totalSpent * 0.20
        ]
        
        return ReportData(
            totalSpent: totalSpent,
            totalBudget: totalBudget,
            budgetUsagePercentage: budgetUsagePercentage,
            expensesByCategory: expensesByCategory,
            expensesByDepartment: expensesByDepartment
        )
    }
}

// MARK: - Forecast Tab View
struct ForecastTabView: View {
    let data: ForecastData
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Budget Forecast")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Projected spending vs budget allocation")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                
                // Chart Card
                VStack(spacing: 16) {
                    Chart {
                        ForEach(Array(data.months.enumerated()), id: \.offset) { index, month in
                            LineMark(
                                x: .value("Month", month),
                                y: .value("Budget", data.budgetData[index])
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .blue.opacity(0.7)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .symbol(.circle)
                            .lineStyle(StrokeStyle(lineWidth: 3, dash: [8, 4]))
                            
                            LineMark(
                                x: .value("Month", month),
                                y: .value("Actual", data.actualData[index])
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.green, .green.opacity(0.7)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .symbol(.circle)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            LineMark(
                                x: .value("Month", month),
                                y: .value("Forecast", data.forecastData[index])
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.orange, .orange.opacity(0.7)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .symbol(.circle)
                            .lineStyle(StrokeStyle(lineWidth: 3, dash: [12, 6]))
                        }
                    }
                    .frame(height: 280)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(.gray.opacity(0.2))
                            AxisValueLabel {
                                if let intValue = value.as(Double.self) {
                                    Text("\(Int(intValue / 1000))K")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                Text(value.as(String.self) ?? "")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Legend
                    VStack(spacing: 12) {
                        legendItem(color: .blue, label: "Budget", style: "dashed")
                        legendItem(color: .green, label: "Actual", style: "solid")
                        legendItem(color: .orange, label: "Forecast", style: "dotted")
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: 10,
                            x: 0,
                            y: 2
                        )
                )
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Variance Tab View
struct VarianceTabView: View {
    let data: VarianceData
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Budget Variance Analysis")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Comparison of planned vs actual spending")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                
                // Chart Card
                VStack(spacing: 16) {
                    Chart {
                        ForEach(Array(data.months.enumerated()), id: \.offset) { index, month in
                            BarMark(
                                x: .value("Month", month),
                                y: .value("Budget", data.budgetData[index])
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .blue.opacity(0.7)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(0.8)
                            
                            BarMark(
                                x: .value("Month", month),
                                y: .value("Actual", data.actualData[index])
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.green, .green.opacity(0.7)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(0.8)
                            
                            BarMark(
                                x: .value("Month", month),
                                y: .value("Forecast", data.forecastData[index])
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.orange, .orange.opacity(0.7)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(0.8)
                        }
                    }
                    .frame(height: 280)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(.gray.opacity(0.2))
                            AxisValueLabel {
                                if let intValue = value.as(Double.self) {
                                    Text("\(Int(intValue / 1000))K")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                Text(value.as(String.self) ?? "")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Legend
                    VStack(spacing: 12) {
                        legendItem(color: .blue, label: "Budget", style: "solid")
                        legendItem(color: .green, label: "Actual", style: "solid")
                        legendItem(color: .orange, label: "Forecast", style: "solid")
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: 10,
                            x: 0,
                            y: 2
                        )
                )
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Trends Tab View
struct TrendsTabView: View {
    let data: [PieChartItem]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spending Trends")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Breakdown by category and department")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                
                // Chart Card
                VStack(spacing: 20) {
                    Chart(data) { item in
                        SectorMark(
                            angle: .value("Percentage", item.percentage),
                            innerRadius: .ratio(0.4),
                            angularInset: 3
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [item.color, item.color.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(0.9)
                    }
                    .frame(height: 280)
                    
                    // Legend
                    VStack(spacing: 12) {
                        ForEach(data) { item in
                            legendItem(color: item.color, label: "\(item.label) (\(String(format: "%.1f", item.percentage))%)", style: "solid")
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: Color.black.opacity(0.05),
                            radius: 10,
                            x: 0,
                            y: 2
                        )
                )
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let label: String
    let style: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Legend indicator
            if style == "dashed" {
                Rectangle()
                    .fill(color)
                    .frame(width: 24, height: 3)
                    .cornerRadius(1.5)
            } else if style == "dotted" {
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                    }
                }
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
            }
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Helper Function
private func legendItem(color: Color, label: String, style: String) -> some View {
    HStack(spacing: 12) {
        // Legend indicator
        if style == "dashed" {
            Rectangle()
                .fill(color)
                .frame(width: 24, height: 3)
                .cornerRadius(1.5)
        } else if style == "dotted" {
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                }
            }
        } else {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        }
        
        Text(label)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.primary)
        
        Spacer()
    }
}