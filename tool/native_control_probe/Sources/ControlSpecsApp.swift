import SwiftUI
@main struct ControlSpecsApp: App {
    init() { PrepareNativeInspection() }
    var body: some Scene {
        WindowGroup {
            ControlsFixture()
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--light") ? .light : .dark)
                .task {
                    try? await Task.sleep(for: .milliseconds(800))
                    let args = ProcessInfo.processInfo.arguments
                    let run = args.firstIndex(of: "--run").map { args[$0 + 1] } ?? "rest"
                    StartMotionLog(run, ["fixture": "native controls", "appearance": args.contains("--light") ? "light" : "dark"], 14)
                }
        }
    }
}
struct ControlsFixture: View {
    @State private var enabled = false
    @State private var value = 0.4
    @State private var segment = 0
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red:0.05,green:0.55,blue:0.55),Color(red:0.04,green:0.12,blue:0.33),Color(red:0.75,green:0.7,blue:0.05)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 28) {
                Text("Native controls").font(.system(size: 28, weight: .bold))
                Text("Switch").font(.system(size: 17, weight: .semibold))
                Toggle("Switch", isOn: $enabled).labelsHidden().accessibilityIdentifier("switch")
                Text("Slider").font(.system(size: 17, weight: .semibold))
                Slider(value: $value).frame(width:300).accessibilityIdentifier("slider")
                Text("Segmented").font(.system(size: 17, weight: .semibold))
                Picker("Segmented", selection: $segment) {
                    Text("First").tag(0)
                    Text("Second").tag(1)
                    Text("Third").tag(2)
                }.pickerStyle(.segmented).frame(width:300).accessibilityIdentifier("segments")
                Text("Disabled").font(.system(size: 17, weight: .semibold))
                HStack {
                    Toggle("Disabled", isOn: .constant(true)).labelsHidden().disabled(true).accessibilityIdentifier("disabled-switch")
                    Slider(value: .constant(0.4)).frame(width:180).disabled(true).accessibilityIdentifier("disabled-slider")
                }
                Picker("Disabled", selection: .constant(1)) {
                    Text("First").tag(0);Text("Second").tag(1);Text("Third").tag(2)
                }.pickerStyle(.segmented).frame(width:300).disabled(true).accessibilityIdentifier("disabled-segments")
                Spacer()
            }.padding(.horizontal,36).padding(.top,36)
        }
    }
}
