import AVFoundation
import SwiftUI

@main
struct DocScanApp: App {
    // TODO: Refactor composition root to have less logic

    let persistenceController = PersistenceController.shared
    let repository: IDocumentsRepository
    @StateObject private var vm: DocumentsViewModel
    @StateObject private var router = Router()

    init() {
        let repository = DocumentsRepository(persistence: persistenceController)
        self.repository = repository
        _vm = StateObject(wrappedValue: DocumentsViewModel(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                DocumentsView(
                    vm: vm,
                    onOpenDetails: { router.push(.documentDetails(id: $0)) },
                    onOpenCamera: { openCameraFlow() }
                )
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case let .documentDetails(id: id):
                        DocumentDetailsView(
                            id: id,
                            repository: repository
                        ) {
                            Task {
                                await vm.deleteDocument(by: id)
                                router.pop()
                            }
                        }
                        .onDisappear {
                            Task { await vm.refreshDocuments() }
                        }
                    }
                }
            }
            .fullScreenCover(item: $router.modal) { modal in
                switch modal {
                case .camera:
                    CameraView { image in
                        Task {
                            guard let id = await vm.createDocument(from: image) else { return }
                            router.dismissModal()
                            router.push(.documentDetails(id: id))
                        }
                    }

                case .cameraPermissions:
                    CameraPermissionsView(
                        onOpenSettings: { openAppSettings() },
                        onCancel: { onCancel() }
                    )
                }
            }
        }
    }

    private func openCameraFlow() {
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                router.present(.camera)

            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                router.present(granted ? .camera : .cameraPermissions)

            case .denied, .restricted:
                router.present(.cameraPermissions)

            @unknown default:
                break
            }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func onCancel() {
        router.dismissModal()
    }
}
