import SwiftUI
@main struct SheetSpecsApp: App {
    init() { PrepareNativeInspection() }
    var body: some Scene {
        WindowGroup {
            SheetFixture().preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--light") ? .light : .dark)
        }
    }
}
struct SheetFixture: View {
    @State private var presented = false
    @State private var selection: PresentationDetent = ProcessInfo.processInfo.arguments.contains("--large") ? .large : .medium
    let mode = ProcessInfo.processInfo.arguments.contains("--light") ? "light" : "dark"
    var body: some View {
        ZStack {
            LinearGradient(colors: [.cyan,.blue,.yellow], startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea()
            Button("Show sheet") { presented = true }.buttonStyle(.glass).accessibilityIdentifier("open")
        }
        .task { try? await Task.sleep(for:.milliseconds(800));StartMotionLog("sheet-\(mode)-\(selection == .large ? "large" : "medium")",["fixture":"native sheet"],14); if ProcessInfo.processInfo.arguments.contains("--auto") { presented = true } }
        .sheet(isPresented:$presented) {
            VStack(spacing:20) {
                HStack {
                    Text("Sheet").font(.system(size:22,weight:.bold)).accessibilityIdentifier("sheet-title")
                    Spacer()
                    Button("Done") { presented = false }.buttonStyle(.glass)
                }.padding(.horizontal,24)
                TextField("Name",text:.constant("")).textFieldStyle(.roundedBorder).padding(.horizontal,24)
                ScrollView {
                    VStack(alignment:.leading,spacing:20) {
                        ForEach(0..<20) { Text("Row \($0)").frame(maxWidth:.infinity,alignment:.leading) }
                    }.padding(.horizontal,24)
                }
            }.padding(.top,24)
            .presentationDetents([.medium,.large],selection:$selection)
            .presentationDragIndicator(.visible)
            .task { try? await Task.sleep(for:.seconds(2));ExtractGlass("sheet-\(mode)-\(selection == .large ? "large" : "medium")-settled",["fixture":"native sheet","appearance":mode,"detent":selection == .large ? "large" : "medium"]); }
        }
    }
}
