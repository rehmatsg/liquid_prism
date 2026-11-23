import SwiftUI

// Opt-in native layout measurements; the TabView owns its actual layout.
struct TabLayoutProbe: View {
    let labels: [String]
    var hideLabels = false
    @State private var selection = 0
    var body: some View {
        TabView(selection: $selection) {
            ForEach(labels.indices, id: \.self) { i in
                Text(labels[i]).tag(i).tabItem {
                    if hideLabels { Image(systemName: "circle") }
                    else { Label(labels[i], systemImage: "circle") }
                }
            }
        }
    }
}
