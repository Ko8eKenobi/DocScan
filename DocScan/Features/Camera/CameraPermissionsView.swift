import SwiftUI

struct CameraPermissionsView: View {
    let onOpenSettings: () -> Void
    let onCancel: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
            Spacer()
            Button {
                onOpenSettings()
            } label: {
                Text("Open Settings")
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            Button("Cancel", role: .cancel) {
                onCancel()
            }
            .padding(.bottom, 24)
        }
        .padding()
    }
}
