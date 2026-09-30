import SwiftUI
import PhotosUI
import AVKit
import Photos

struct Movie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { f in
            let dst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try FileManager.default.copyItem(at: f.file, to: dst)
            return Movie(url: dst)
        }
    }
}

struct ContentView: View {
    @State private var pick: PhotosPickerItem?
    @State private var asset: AVAsset?
    @State private var player = AVPlayer()
    @State private var look = Look()
    @State private var preset = "Original"
    @State private var status = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.03, blue: 0.10), Color(red: 0.10, green: 0.04, blue: 0.20)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text("LUMEN").font(.system(size: 30, weight: .black, design: .rounded)).tracking(6)
                        .foregroundStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing))
                    ZStack {
                        RoundedRectangle(cornerRadius: 24).fill(.black.opacity(0.4))
                        if asset != nil { VideoPlayer(player: player).clipShape(RoundedRectangle(cornerRadius: 24)) }
                        else { Text("Wähle ein Video").foregroundStyle(.secondary) }
                    }
                    .frame(height: 340)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                    .shadow(color: .purple.opacity(0.4), radius: 20)

                    PhotosPicker(selection: $pick, matching: .videos) { pill("Video auswählen", "video.badge.plus") }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(LooksEngine.presets, id: \.0) { p in
                            Button { preset = p.0; look = p.1 } label: {
                                Text(p.0).font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(preset == p.0 ? AnyShapeStyle(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(.ultraThinMaterial), in: Capsule())
                            }.buttonStyle(.plain)
                        } }
                    }

                    VStack(spacing: 10) {
                        slider("Belichtung", $look.exposure, -1...1)
                        slider("Kontrast", $look.contrast, 0.5...1.6)
                        slider("Sättigung", $look.saturation, 0...2)
                        slider("Temperatur", $look.temperature, 3500...9500)
                        slider("Glow", $look.glow, 0...2)
                        slider("Vignette", $look.vignette, 0...1)
                        slider("Grain", $look.grain, 0...1)
                        slider("Fade", $look.fade, 0...1)
                    }
                    .padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))

                    Button { Task { await export() } } label: { pill("Exportieren", "square.and.arrow.down") }
                        .disabled(asset == nil)
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
        }
        .onChange(of: pick) { item in
            Task {
                guard let m = try? await item?.loadTransferable(type: Movie.self) else { return }
                let a = AVURLAsset(url: m.url); asset = a
                player.replaceCurrentItem(with: AVPlayerItem(asset: a)); refresh(); player.play()
            }
        }
        .onChange(of: look) { _ in refresh() }
    }

    func comp(_ a: AVAsset) -> AVVideoComposition {
        let l = look
        return AVVideoComposition(asset: a) { req in
            req.finish(with: LooksEngine.apply(l, to: req.sourceImage.clampedToExtent()).cropped(to: req.sourceImage.extent), context: nil)
        }
    }

    func refresh() {
        guard let a = asset else { return }
        player.currentItem?.videoComposition = comp(a)
    }

    func export() async {
        guard let a = asset, let s = AVAssetExportSession(asset: a, presetName: AVAssetExportPresetHighestQuality) else { return }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("lumen-\(UUID().uuidString).mov")
        s.outputURL = out; s.outputFileType = .mov; s.videoComposition = comp(a)
        status = "Exportiere…"
        await withCheckedContinuation { c in s.exportAsynchronously { c.resume() } }
        guard s.status == .completed else { status = "Export fehlgeschlagen"; return }
        do {
            try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: out) }
            status = "In Fotos gespeichert ✓"
        } catch { status = "Speichern fehlgeschlagen" }
    }

    func pill(_ t: String, _ icon: String) -> some View {
        Label(t, systemImage: icon).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing), in: Capsule())
            .foregroundStyle(.white)
    }

    func slider(_ n: String, _ v: Binding<Double>, _ r: ClosedRange<Double>) -> some View {
        HStack { Text(n).font(.caption).frame(width: 84, alignment: .leading); Slider(value: v, in: r).tint(.cyan) }
    }
}
