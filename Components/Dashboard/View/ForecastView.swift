import SwiftUI
import Charts

struct ForecastView: View {
    var data: ForecastData
    
    var body: some View {
        VStack {
            Text("Forecast Report")
                .font(.headline)
                .foregroundColor(.purple)
            
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
        }
        .padding()
    }
}
