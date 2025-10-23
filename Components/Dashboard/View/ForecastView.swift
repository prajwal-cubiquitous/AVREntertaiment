import SwiftUI
import Charts

@available(iOS 14.0, *)
struct ForecastView: View {
    var data: ForecastData
    
    var body: some View {
        VStack {
            Text("Forecast Report")
                .font(.headline)
                .foregroundColor(.purple)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(data.months.enumerated()), id: \.offset) { index, month in
                        LineMark(
                            x: .value("Month", month),
                            y: .value("Budget", data.budgetData[index])
                        )
                        .foregroundStyle(.blue)
                        .symbol(.circle)
                        
                        LineMark(
                            x: .value("Month", month),
                            y: .value("Actual", data.actualData[index])
                        )
                        .foregroundStyle(.purple)
                        .symbol(.circle)
                        
                        LineMark(
                            x: .value("Month", month),
                            y: .value("Forecast", data.forecastData[index])
                        )
                        .foregroundStyle(.green)
                        .symbol(.circle)
                    }
                }
                .frame(height: 250)
            } else {
                // Fallback for iOS 13-15
                VStack(spacing: 16) {
                    Text("Forecast Data")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(data.months.enumerated()), id: \.offset) { index, month in
                            HStack {
                                Text(month)
                                    .frame(width: 80, alignment: .leading)
                                
                                Text("Budget: \(Int(data.budgetData[index]))")
                                    .foregroundColor(.blue)
                                
                                Spacer()
                                
                                Text("Actual: \(Int(data.actualData[index]))")
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                Text("Forecast: \(Int(data.forecastData[index]))")
                                    .foregroundColor(.green)
                            }
                            .font(.caption)
                        }
                    }
                }
                .frame(height: 250)
            }
        }
        .padding()
    }
}
