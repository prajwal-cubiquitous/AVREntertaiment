//
//  LineChartView.swift
//  AVREntertainment
//
//  Created by Prajwal S S Reddy on 10/9/25.
//
import SwiftUI
import Charts


struct LineChartView: View {
    var data: [MonthlyData]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Budget vs Actual vs Forecast")
                .font(.title3)
                .bold()
                .padding(.bottom, 8)
            
            Chart {
                // Budget Line (Blue)
                ForEach(data) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.budget),
                        series: .value("Type", "Budget")
                    )
                    .foregroundStyle(.blue)
                }
                
                // Actual Line (Purple)
                ForEach(data) { item in
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
                ForEach(data) { item in
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
        .padding()
    }
}

// MARK: - Preview
#Preview {
    LineChartView(data: MonthlyData.sampleData)
}


