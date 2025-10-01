import SwiftUI
import Charts

struct ForecastView: View {
    var data: [ForecastData]
    
    var body: some View {
        VStack {
            Text("Forecast Report")
                .font(.headline)
                .foregroundColor(.purple)
            
            Chart {
                ForEach(data, id: \.month) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Budget", item.budget)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.circle)
                    
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Actual", item.actual)
                    )
                    .foregroundStyle(.purple)
                    .symbol(.circle)
                    
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Forecast", item.forecast)
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
