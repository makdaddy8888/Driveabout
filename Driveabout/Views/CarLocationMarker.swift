import SwiftUI

struct CarLocationMarker: View {
    var rotationDegrees: Double?

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

            Image(systemName: "car.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .rotationEffect(rotationDegrees.map { .degrees($0) } ?? .zero)
        }
        .accessibilityLabel("Your location")
    }
}

#Preview {
    CarLocationMarker(rotationDegrees: 45)
        .padding()
}
