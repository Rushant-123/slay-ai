//
//  FilterPreset.swift
//  SnatchShot
//
//  Created by SnatchShot on 01/01/25.
//

import Foundation

// MARK: - Filter Preset Modules
struct FilterPresetModules: Codable {
    // Basic Color Adjustments
    var temperature: Double      // -40 to +40 (warmer = positive)
    var tint: Double            // -30 to +30 (green ←→ magenta)
    var exposure: Double        // -2 to +2 (stops)
    var contrast: Double        // -1 to +1
    var saturation: Double      // -1 to +1

    // Effects
    var grain: Double           // 0 to 1
    var vignette: Double        // 0 to 1
    var halation: Double        // 0 to 1
    var chromaticAberration: Double // 0 to 1
    var chromaBleed: Double     // 0 to 1

    // Digital/Retro Effects
    var downscale: Double       // 0 to 1 (1 = strongest pixelation)
    var scanlines: Double       // 0 to 1
    var interlace: Double       // 0 to 1

    // LUT and Special Effects
    var lut: String?            // LUT identifier
    var frame: String?          // Frame/border identifier
    var lightLeak: String?      // Light leak effect
    var edgeBurn: Double        // 0 to 1
    var blackLift: Double       // 0 to 1
    var edgeFade: Double        // 0 to 1
    var lensDistortion: String? // Lens distortion preset
    var jitter: Double          // 0 to 1 (horizontal jitter)
    var timestamp: Bool         // Show timestamp overlay
    var skinSmooth: Double      // 0 to 1 (portrait smoothing)
    var posterize: Bool         // Posterization effect
    var edgeEnhance: Double     // 0 to 1 (edge enhancement)
    var sharpen: Double         // 0 to 1 (sharpening)

    init(
        temperature: Double = 0.0,
        tint: Double = 0.0,
        exposure: Double = 0.0,
        contrast: Double = 0.0,
        saturation: Double = 0.0,
        grain: Double = 0.0,
        vignette: Double = 0.0,
        halation: Double = 0.0,
        chromaticAberration: Double = 0.0,
        chromaBleed: Double = 0.0,
        downscale: Double = 0.0,
        scanlines: Double = 0.0,
        interlace: Double = 0.0,
        lut: String? = nil,
        frame: String? = nil,
        lightLeak: String? = nil,
        edgeBurn: Double = 0.0,
        blackLift: Double = 0.0,
        edgeFade: Double = 0.0,
        lensDistortion: String? = nil,
        jitter: Double = 0.0,
        timestamp: Bool = false,
        skinSmooth: Double = 0.0,
        posterize: Bool = false,
        edgeEnhance: Double = 0.0,
        sharpen: Double = 0.0
    ) {
        self.temperature = temperature
        self.tint = tint
        self.exposure = exposure
        self.contrast = contrast
        self.saturation = saturation
        self.grain = grain
        self.vignette = vignette
        self.halation = halation
        self.chromaticAberration = chromaticAberration
        self.chromaBleed = chromaBleed
        self.downscale = downscale
        self.scanlines = scanlines
        self.interlace = interlace
        self.lut = lut
        self.frame = frame
        self.lightLeak = lightLeak
        self.edgeBurn = edgeBurn
        self.blackLift = blackLift
        self.edgeFade = edgeFade
        self.lensDistortion = lensDistortion
        self.jitter = jitter
        self.timestamp = timestamp
        self.skinSmooth = skinSmooth
        self.posterize = posterize
        self.edgeEnhance = edgeEnhance
        self.sharpen = sharpen
    }

    private enum CodingKeys: String, CodingKey {
        case temperature, tint, exposure, contrast, saturation
        case grain, vignette, halation, chromaticAberration, chromaBleed = "chroma_bleed"
        case downscale, scanlines, interlace
        case lut, frame, lightLeak = "light_leak", edgeBurn = "edge_burn"
        case blackLift = "black_lift", edgeFade = "edge_fade", lensDistortion = "lens_distortion"
        case jitter, timestamp, skinSmooth = "skin_smooth", posterize, edgeEnhance = "edge_enhance", sharpen
    }
}

// MARK: - Filter Preset
struct FilterPreset: Identifiable, Codable {
    let id: String
    let name: String
    let source: String // "DazzCam", "KAPI", "LoFiCam"
    let description: String
    let modules: FilterPresetModules

    var displayName: String {
        "\(source): \(name)"
    }

    var category: String {
        switch source {
        case "DazzCam": return "Film"
        case "KAPI": return "Digital"
        case "LoFiCam": return "Retro"
        default: return "Custom"
        }
    }
}

// MARK: - Filter Preset Manager
class FilterPresetManager {
    static let shared = FilterPresetManager()

    private(set) var presets: [FilterPreset] = []

    private init() {
        loadPresets()
    }

    private func loadPresets() {
        // Load the 30 presets from embedded JSON
        presets = loadPresetData()
    }

    private func loadPresetData() -> [FilterPreset] {
        // Dazz Cam presets
        let dazzPresets = [
            FilterPreset(
                id: "dazz_portra_warm",
                name: "Portra Warm",
                source: "DazzCam",
                description: "Soft warm film, natural skin tones, medium grain.",
                modules: FilterPresetModules(
                    temperature: 18, tint: 4, exposure: 0.05, contrast: 0.12, saturation: 0.08,
                    grain: 0.36, vignette: 0.12, halation: 0.08,
                    lut: "portra_like"
                )
            ),
            FilterPreset(
                id: "dazz_kodak_gold",
                name: "Kodak Gold",
                source: "DazzCam",
                description: "Slightly punchy, warm highlights, film grain.",
                modules: FilterPresetModules(
                    temperature: 20, tint: 2, exposure: 0.08, contrast: 0.18, saturation: 0.18,
                    grain: 0.32, vignette: 0.10,
                    lut: "kodak_gold_like"
                )
            ),
            FilterPreset(
                id: "dazz_kodachrome_punch",
                name: "Kodachrome Punch",
                source: "DazzCam",
                description: "High saturation and contrast, vivid greens/reds.",
                modules: FilterPresetModules(
                    temperature: 6, tint: -2, contrast: 0.35, saturation: 0.35,
                    grain: 0.18, halation: 0.10,
                    lut: "kodachrome_like"
                )
            ),
            FilterPreset(
                id: "dazz_polaroid_fade",
                name: "Polaroid Fade",
                source: "DazzCam",
                description: "Faded instant film with white frame and edge yellowing.",
                modules: FilterPresetModules(
                    temperature: 10, tint: 6, exposure: 0.03, contrast: -0.08, saturation: -0.28,
                    grain: 0.28, vignette: 0.18,
                    lut: "polaroid_fade", frame: "polaroid_white", edgeBurn: 0.22
                )
            ),
            FilterPreset(
                id: "dazz_bleach_bypass",
                name: "Bleach Bypass",
                source: "DazzCam",
                description: "High contrast, desaturated midtones — dramatic cinematic look.",
                modules: FilterPresetModules(
                    temperature: -2, exposure: -0.02, contrast: 0.48, saturation: -0.42,
                    grain: 0.22, vignette: 0.08,
                    lut: "bleach_bypass"
                )
            ),
            FilterPreset(
                id: "dazz_faded_retro",
                name: "Faded Retro",
                source: "DazzCam",
                description: "Sun-faded, warm cast, soft grain and light leak flair.",
                modules: FilterPresetModules(
                    temperature: 14, tint: 8, exposure: 0.12, contrast: -0.12, saturation: -0.22,
                    grain: 0.42, vignette: 0.20,
                    lut: "retro_fade", lightLeak: "top_right_soft"
                )
            ),
            FilterPreset(
                id: "dazz_matte_film",
                name: "Matte Film",
                source: "DazzCam",
                description: "Lifted blacks, soft contrast — modern indie matte.",
                modules: FilterPresetModules(
                    temperature: 4, contrast: -0.18, saturation: -0.04,
                    grain: 0.14, vignette: 0.06,
                    lut: "matte_like", blackLift: 0.22
                )
            ),
            FilterPreset(
                id: "dazz_sun_bleached",
                name: "Sun Bleached",
                source: "DazzCam",
                description: "Very warm center, lowered saturation, raised highlights.",
                modules: FilterPresetModules(
                    temperature: 24, tint: 6, exposure: 0.25, contrast: -0.10, saturation: -0.40,
                    grain: 0.26, vignette: 0.14,
                    lut: "sun_bleach", edgeFade: 0.18
                )
            ),
            FilterPreset(
                id: "dazz_grainy_street",
                name: "Gritty Street",
                source: "DazzCam",
                description: "High grain, sharpened mid-contrast — documentary style.",
                modules: FilterPresetModules(
                    temperature: 2, exposure: -0.05, contrast: 0.22, saturation: -0.12,
                    grain: 0.78, vignette: 0.28,
                    lut: "neutral", sharpen: 0.25
                )
            ),
            FilterPreset(
                id: "dazz_creamy_portrait",
                name: "Creamy Portrait",
                source: "DazzCam",
                description: "Portrait softening, gentle warm toning, subtle halation.",
                modules: FilterPresetModules(
                    temperature: 12, tint: 3, exposure: 0.05, contrast: -0.06, saturation: 0.06,
                    grain: 0.18, vignette: 0.06, halation: 0.18,
                    lut: "portra_soft", skinSmooth: 0.22
                )
            )
        ]

        // KAPI presets
        let kapiPresets = [
            FilterPreset(
                id: "kapi_nokia_classic",
                name: "Nokia 2005",
                source: "KAPI",
                description: "Low-res early phone camera vibe: blue cast + heavy noise.",
                modules: FilterPresetModules(
                    temperature: -10, tint: -6, exposure: -0.15, contrast: -0.22, saturation: -0.30,
                    grain: 0.78, chromaticAberration: 0.28,
                    downscale: 0.55,
                    lut: "nokia_like"
                )
            ),
            FilterPreset(
                id: "kapi_dv_2003",
                name: "DV 2003",
                source: "KAPI",
                description: "Camcorder feel: interlace, mild blue/green cast, scanlines.",
                modules: FilterPresetModules(
                    temperature: -8, tint: -4, contrast: 0.04, saturation: 0.02,
                    grain: 0.30,
                    downscale: 0.0, scanlines: 0.52, interlace: 0.48,
                    lut: "dv_cam", timestamp: true
                )
            ),
            FilterPreset(
                id: "kapi_ccd_warm",
                name: "CCD Warm",
                source: "KAPI",
                description: "Old CCD sensor warmth + slight bloom on highlights.",
                modules: FilterPresetModules(
                    temperature: 18, tint: 2, exposure: 0.05, contrast: 0.06, saturation: 0.06,
                    grain: 0.42, halation: 0.22, chromaticAberration: 0.12,
                    lut: "ccd_warm"
                )
            ),
            FilterPreset(
                id: "kapi_lomo_tilt",
                name: "Lomo Toy",
                source: "KAPI",
                description: "Vivid color shift, strong vignette and lens distortion.",
                modules: FilterPresetModules(
                    temperature: 8, tint: -6, exposure: -0.02, contrast: 0.28, saturation: 0.42,
                    grain: 0.36, vignette: 0.46,
                    lut: "lomo_like",
                    lensDistortion: "fisheye_0.6"
                )
            ),
            FilterPreset(
                id: "kapi_vhs_warble",
                name: "VHS Warble",
                source: "KAPI",
                description: "VHS artifacts + horizontal jitter + chroma bleed.",
                modules: FilterPresetModules(
                    temperature: -6, contrast: -0.10, saturation: -0.06,
                    grain: 0.44, chromaBleed: 0.62,
                    scanlines: 0.44,
                    lut: "vhs_like",
                    jitter: 0.34, timestamp: true
                )
            )
        ]

        // LoFi Cam presets
        let lofiPresets = [
            FilterPreset(
                id: "lofi_t10",
                name: "T10 Classic",
                source: "LoFiCam",
                description: "Ricoh/point-and-shoot inspired: punchy contrast with tiny grain.",
                modules: FilterPresetModules(
                    temperature: 6, contrast: 0.20, saturation: 0.12,
                    grain: 0.16, vignette: 0.10,
                    lut: "t10_like"
                )
            ),
            FilterPreset(
                id: "lofi_f700",
                name: "F700 Retro",
                source: "LoFiCam",
                description: "Soft highlights, cool shadow cast, subtle film texture.",
                modules: FilterPresetModules(
                    temperature: -8, tint: -2, exposure: 0.04, contrast: -0.04, saturation: 0.02,
                    grain: 0.24, halation: 0.12,
                    lut: "f700_like"
                )
            ),
            FilterPreset(
                id: "lofi_grd_bw",
                name: "GRD B&W",
                source: "LoFiCam",
                description: "Ricoh GR–style monochrome with crisp micro-contrast.",
                modules: FilterPresetModules(
                    contrast: 0.32, saturation: -1.0,
                    grain: 0.28, vignette: 0.18,
                    lut: "grd_bw", blackLift: -0.02
                )
            ),
            FilterPreset(
                id: "lofi_120_film",
                name: "120 Medium Format",
                source: "LoFiCam",
                description: "Soft tonal rolloff, larger grain, gentle warmth.",
                modules: FilterPresetModules(
                    temperature: 12, tint: 2, exposure: 0.08, contrast: -0.06, saturation: 0.06,
                    grain: 0.44, vignette: 0.08,
                    lut: "120_like"
                )
            ),
            FilterPreset(
                id: "lofi_l80_soft",
                name: "L80 Soft",
                source: "LoFiCam",
                description: "Toy cam softness, slightly desaturated and warm edges.",
                modules: FilterPresetModules(
                    temperature: 10, tint: 4, exposure: 0.02, contrast: -0.10, saturation: -0.08,
                    grain: 0.30,
                    lut: "l80_like", edgeFade: 0.22
                )
            ),
            FilterPreset(
                id: "lofi_fuji_velvia",
                name: "Fuji Velvia (LoFi)",
                source: "LoFiCam",
                description: "Saturated greens and reds, punchy contrast — landscape favorite.",
                modules: FilterPresetModules(
                    contrast: 0.38, saturation: 0.44, grain: 0.16,
                    lut: "fuji_velvia"
                )
            ),
            FilterPreset(
                id: "lofi_dispo_film",
                name: "Dispo.F",
                source: "LoFiCam",
                description: "Disposable camera look — warm center, light leaks, bold grain.",
                modules: FilterPresetModules(
                    temperature: 18, tint: 6, exposure: 0.06, contrast: 0.04, saturation: -0.06,
                    grain: 0.62, vignette: 0.26,
                    lut: "dispo_like", lightLeak: "bottom_left"
                )
            ),
            FilterPreset(
                id: "lofi_classic_lomo",
                name: "Classic Lomo",
                source: "LoFiCam",
                description: "Strong vignette, shifted colors and slightly boosted saturation.",
                modules: FilterPresetModules(
                    temperature: 8, tint: -8, exposure: -0.03, contrast: 0.30, saturation: 0.28,
                    grain: 0.36, vignette: 0.52, chromaticAberration: 0.18,
                    lut: "lomo_classic"
                )
            ),
            FilterPreset(
                id: "lofi_neon_night",
                name: "Neon Night",
                source: "LoFiCam",
                description: "Boosted blues and magentas, glow on highlights for night scenes.",
                modules: FilterPresetModules(
                    temperature: -18, tint: 14, exposure: -0.08, contrast: 0.22, saturation: 0.18,
                    grain: 0.26, vignette: 0.14, halation: 0.32,
                    lut: "neon_boost"
                )
            ),
            FilterPreset(
                id: "lofi_pastel_film",
                name: "Pastel Film",
                source: "LoFiCam",
                description: "Soft, desaturated pastel tones and low contrast — dreamy.",
                modules: FilterPresetModules(
                    temperature: 8, tint: 6, exposure: 0.06, contrast: -0.22, saturation: -0.36,
                    grain: 0.12, vignette: 0.04,
                    lut: "pastel_like"
                )
            )
        ]

        return dazzPresets + kapiPresets + lofiPresets
    }

    func getPreset(by id: String) -> FilterPreset? {
        return presets.first { $0.id == id }
    }

    func getPresets(for source: String) -> [FilterPreset] {
        return presets.filter { $0.source == source }
    }

    func getPresetsByCategory() -> [String: [FilterPreset]] {
        return Dictionary(grouping: presets) { $0.category }
    }
}
