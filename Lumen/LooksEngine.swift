import CoreImage
import CoreImage.CIFilterBuiltins

struct Look: Equatable {
    var exposure = 0.0
    var contrast = 1.0
    var saturation = 1.0
    var temperature = 6500.0
    var glow = 0.0
    var vignette = 0.0
    var grain = 0.0
    var fade = 0.0
}

enum LooksEngine {
    static let presets: [(String, Look)] = [
        ("Original", Look()),
        ("Neon Night", Look(exposure: -0.1, contrast: 1.25, saturation: 1.4, temperature: 5200, glow: 1.0, vignette: 0.4)),
        ("Warm Film", Look(exposure: 0.05, contrast: 1.1, saturation: 0.9, temperature: 7800, vignette: 0.3, grain: 0.4, fade: 0.3)),
        ("Cold Anime", Look(exposure: 0.1, contrast: 1.2, saturation: 1.3, temperature: 4800, glow: 0.6)),
        ("Faded", Look(contrast: 0.9, saturation: 0.7, grain: 0.3, fade: 0.7))
    ]

    static func apply(_ l: Look, to src: CIImage) -> CIImage {
        let extent = src.extent
        var i = src
        let ex = CIFilter.exposureAdjust(); ex.inputImage = i; ex.ev = Float(l.exposure)
        i = ex.outputImage ?? i
        let cc = CIFilter.colorControls(); cc.inputImage = i
        cc.contrast = Float(l.contrast); cc.saturation = Float(l.saturation)
        i = cc.outputImage ?? i
        let t = CIFilter.temperatureAndTint(); t.inputImage = i
        t.neutral = CIVector(x: 6500, y: 0); t.targetNeutral = CIVector(x: CGFloat(l.temperature), y: 0)
        i = t.outputImage ?? i
        if l.fade > 0 {
            let b = CGFloat(l.fade) * 0.12
            i = i.applyingFilter("CIColorMatrix", parameters: ["inputBiasVector": CIVector(x: b, y: b, z: b, w: 0)])
        }
        if l.glow > 0 {
            let b = CIFilter.bloom(); b.inputImage = i; b.intensity = Float(l.glow); b.radius = 25
            i = b.outputImage ?? i
        }
        if l.vignette > 0 {
            let v = CIFilter.vignette(); v.inputImage = i; v.intensity = Float(l.vignette * 2); v.radius = 2
            i = v.outputImage ?? i
        }
        if l.grain > 0 {
            let n = CIFilter.randomGenerator().outputImage!.cropped(to: extent)
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(l.grain) * 0.18)])
            i = n.composited(over: i)
        }
        return i.cropped(to: extent)
    }
}
