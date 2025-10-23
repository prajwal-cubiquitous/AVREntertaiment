//
//  AnalysisView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/1/25.
//

import SwiftUI
import Charts

struct AnalysisView: View {
    let projectId: String
    let reportData: ReportData
    @StateObject private var viewModel = AnalysisViewModel()
    @Environment(\.compatibleDismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Tab Selector
                tabSelector
                
                // Content
                contentView
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadAnalysis(for: reportData)
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
                // Back button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
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
                
                // Refresh button
                Button(action: { viewModel.refreshAnalysis(for: reportData) }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.2))
                        )
                }
                .buttonStyle(PlainButtonStyle())
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
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.selectTab(index)
                    }
                }) {
                    Text(viewModel.tabs[index])
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(viewModel.selectedTab == index ? .white : Color(.systemGray))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(viewModel.selectedTab == index ? 
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
    
    // MARK: - Content View
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(errorMessage)
            } else if let results = viewModel.analysisResults {
                analysisContentView(results)
            } else {
                emptyView
            }
        }
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
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: viewModel.isLoading)
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
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 12) {
                Text("Unable to Load Analysis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Retry button
            Button(action: { viewModel.refreshAnalysis(for: reportData) }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                    Text("Try Again")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(red: 0.545, green: 0.373, blue: 0.749))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
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
    
    // MARK: - Analysis Content View
    private func analysisContentView(_ results: AnalysisResults) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Summary Cards
                summaryCardsView(results)
                
                // Analysis Content based on selected tab
                switch viewModel.selectedTab {
                case 0:
                    forecastView(results.forecastData)
                case 1:
                    varianceView(results.varianceData)
                case 2:
                    trendsView(results.trendsData)
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Summary Cards
    private func summaryCardsView(_ results: AnalysisResults) -> some View {
        VStack(spacing: 16) {
            // Main summary card
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total Spent")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        Text(formatCurrency(results.totalSpent))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Budget Usage")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        Text("\(String(format: "%.1f", results.budgetUsagePercentage))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(budgetUsageColor(results.budgetUsagePercentage))
                    }
                }
                
                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Budget Progress")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", results.budgetUsagePercentage))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(budgetUsageColor(results.budgetUsagePercentage))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            budgetUsageColor(results.budgetUsagePercentage),
                                            budgetUsageColor(results.budgetUsagePercentage).opacity(0.7)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * min(results.budgetUsagePercentage / 100, 1), height: 8)
                        }
                    }
                    .frame(height: 8)
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
        }
    }
    
    // MARK: - Forecast View
    private func forecastView(_ data: ForecastData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Budget Forecast")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Projected spending vs budget allocation")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            // Chart card
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
                forecastLegend
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
        }
    }
    
    // MARK: - Variance View
    private func varianceView(_ data: VarianceData) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Budget Variance Analysis")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Comparison of planned vs actual spending")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            // Chart card
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
                varianceLegend
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
        }
    }
    
    // MARK: - Trends View
    private func trendsView(_ data: [PieChartItem]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Spending Trends")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Breakdown by category and department")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            // Chart card
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
                trendsLegend(data)
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
        }
    }
    
    // MARK: - Legends
    private var forecastLegend: some View {
        VStack(spacing: 12) {
            legendItem(color: .blue, label: "Budget", style: "dashed")
            legendItem(color: .green, label: "Actual", style: "solid")
            legendItem(color: .orange, label: "Forecast", style: "dotted")
        }
    }
    
    private var varianceLegend: some View {
        VStack(spacing: 12) {
            legendItem(color: .blue, label: "Budget", style: "solid")
            legendItem(color: .green, label: "Actual", style: "solid")
            legendItem(color: .orange, label: "Forecast", style: "solid")
        }
    }
    
    private func trendsLegend(_ data: [PieChartItem]) -> some View {
        VStack(spacing: 12) {
            ForEach(data) { item in
                legendItem(color: item.color, label: "\(item.label) (\(String(format: "%.1f", item.percentage))%)", style: "solid")
            }
        }
    }
    
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
    
    // MARK: - Helper Methods
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
    
    private func budgetUsageColor(_ percentage: Double) -> Color {
        if percentage <= 80 {
            return .green
        } else if percentage <= 100 {
            return .orange
        } else {
            return .red
        }
    }
}