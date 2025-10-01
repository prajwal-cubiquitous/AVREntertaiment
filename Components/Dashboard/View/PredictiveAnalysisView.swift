import SwiftUI
import Charts

struct PredictiveAnalysisView: View {
    let project: Project
    @State private var selectedTab = 0
    @State private var forecastData: [ForecastData] = []
    @State private var varianceData: [VarianceData] = []
    @State private var trendsData: [TrendsData] = []
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
            // Top Navigation Bar
            HStack {
                Button(action: {}) {
                    Image(systemName: "line.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("Predictive Analysis")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Segmented Control
    private var segmentedControl: some View {
        HStack(spacing: 4) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = index
                    }
                }) {
                    Text(tabs[index])
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTab == index ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == index ? Color.accentColor : Color(.systemGray6))
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
                ProgressView("Loading analysis data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch selectedTab {
                case 0:
                    ForecastTabView(data: forecastData)
                case 1:
                    VarianceTabView(data: varianceData)
                case 2:
                    TrendsTabView(data: trendsData)
                default:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Data Loading
    private func loadAllData() {
        guard let projectId = project.id else { return }
        
        // Load forecast data
        fetchForecastData(for: projectId) { data in
            DispatchQueue.main.async {
                self.forecastData = data
                self.checkLoadingComplete()
            }
        }
        
        // Load variance data
        loadVarianceData(for: projectId)
        
        // Load trends data
        loadTrendsData(for: projectId)
    }
    
    private func loadVarianceData(for projectId: String) {
        // Generate sample variance data
        let months = ["Jan", "Feb", "Mar", "Apr", "May"]
        var data: [VarianceData] = []
        
        for month in months {
            let budget = Double.random(in: 5000...6000)
            let actual = budget + Double.random(in: -500...1000)
            let forecast = actual * Double.random(in: 1.0...1.1)
            
            data.append(VarianceData(
                month: month,
                budget: budget,
                actual: actual,
                forecast: forecast
            ))
        }
        
        DispatchQueue.main.async {
            self.varianceData = data
            self.checkLoadingComplete()
        }
    }
    
    private func loadTrendsData(for projectId: String) {
        // Generate sample trends data
        let data = [
            TrendsData(category: "Travel", percentage: 45, color: .blue),
            TrendsData(category: "Meals", percentage: 30, color: .purple),
            TrendsData(category: "Misc", percentage: 25, color: .green)
        ]
        
        DispatchQueue.main.async {
            self.trendsData = data
            self.checkLoadingComplete()
        }
    }
    
    private func checkLoadingComplete() {
        if !forecastData.isEmpty && !varianceData.isEmpty && !trendsData.isEmpty {
            isLoading = false
        }
    }
}

// MARK: - Data Models
struct VarianceData {
    let month: String
    let budget: Double
    let actual: Double
    let forecast: Double
}

struct TrendsData {
    let category: String
    let percentage: Double
    let color: Color
}

// MARK: - Forecast Tab View
struct ForecastTabView: View {
    let data: [ForecastData]
    
    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Forecast Report")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Line Chart
            Chart {
                ForEach(data, id: \.month) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Cost", item.budget)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Cost", item.actual)
                    )
                    .foregroundStyle(.purple)
                    .symbol(.circle)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Cost", item.forecast)
                    )
                    .foregroundStyle(.green)
                    .symbol(.circle)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
            }
            .frame(height: 300)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(.gray.opacity(0.3))
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text("\(Int(intValue))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        Text(value.as(String.self) ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Legend
            HStack(spacing: 24) {
                LegendItem(color: .blue, label: "Budget")
                LegendItem(color: .purple, label: "Actual")
                LegendItem(color: .green, label: "Forecast")
            }
        }
        .padding(24)
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
}

// MARK: - Variance Tab View
struct VarianceTabView: View {
    let data: [VarianceData]
    
    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Variance Analysis")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Bar Chart
            Chart {
                ForEach(data, id: \.month) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Cost", item.budget)
                    )
                    .foregroundStyle(.blue)
                    
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Cost", item.actual)
                    )
                    .foregroundStyle(.purple)
                    
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Cost", item.forecast)
                    )
                    .foregroundStyle(.green)
                }
            }
            .frame(height: 300)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(.gray.opacity(0.3))
                    AxisValueLabel {
                        if let intValue = value.as(Double.self) {
                            Text("\(Int(intValue))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        Text(value.as(String.self) ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Legend
            HStack(spacing: 24) {
                LegendItem(color: .blue, label: "Budget")
                LegendItem(color: .purple, label: "Actual")
                LegendItem(color: .green, label: "Forecast")
            }
        }
        .padding(24)
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
}

// MARK: - Trends Tab View
struct TrendsTabView: View {
    let data: [TrendsData]
    
    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Trends Analysis")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Pie Chart
            Chart(data, id: \.category) { item in
                SectorMark(
                    angle: .value("Percentage", item.percentage),
                    innerRadius: .ratio(0.3),
                    angularInset: 2
                )
                .foregroundStyle(item.color)
                .opacity(0.8)
            }
            .frame(height: 300)
            
            // Legend
            VStack(spacing: 16) {
                ForEach(data, id: \.category) { item in
                    HStack {
                        Circle()
                            .fill(item.color)
                            .frame(width: 16, height: 16)
                        
                        Text(item.category)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(Int(item.percentage))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(item.color)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(24)
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
}

// MARK: - Legend Item
struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}
