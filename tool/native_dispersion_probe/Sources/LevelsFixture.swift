import SwiftUI

/// --scene levels: regular and clear glass over flat sRGB grey bands, with a
/// bare strip on the right as the reference, to read how the glass face maps
/// each backdrop level. Each band is 56 points tall, so its middle stays clear
/// of the neighbouring bands under the frost. `--levels 0,32,64` replaces the
/// default grey levels; `--top P` moves the bands below the status bar.
struct LevelsFixture: View {
    /// 8-bit sRGB levels, top to bottom; the last band is the grouped
    /// background (242, 242, 247), for hue.
    static let levels: [(Double, Double, Double)] =
        (value("--levels", "").isEmpty
            ? [128, 160, 192, 208, 224, 232, 238, 242, 246, 250, 253, 255]
            : value("--levels", "").split(separator: ",").compactMap { Double($0) })
        .map { ($0, $0, $0) } + [(242, 242, 247)]
    static let top = Double(value("--top", "0")) ?? 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Color.white.frame(height: Self.top)
                ForEach(Self.levels.indices, id: \.self) { i in
                    let l = Self.levels[i]
                    Color(.sRGB, red: l.0 / 255, green: l.1 / 255, blue: l.2 / 255)
                        .frame(height: 56)
                }
                Color.white
            }
            HStack(spacing: 40) {
                RoundedRectangle(cornerRadius: 28).fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))
                    .frame(width: 120, height: 56 * 13 + 40)
                RoundedRectangle(cornerRadius: 28).fill(.clear)
                    .glassEffect(.clear, in: .rect(cornerRadius: 28))
                    .frame(width: 120, height: 56 * 13 + 40)
            }
            .padding(.leading, 30)
            .offset(y: Self.top - 20)
        }
        .ignoresSafeArea()
    }
}
