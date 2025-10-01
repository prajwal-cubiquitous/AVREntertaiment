import SwiftUI

struct AnalyticsView: View {
    let project: Project
    
    var body: some View {
        PredictiveAnalysisView(project: project)
    }
}
