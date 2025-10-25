//
//  FilterSelectionView.swift
//  SnatchShot
//
//  Created by SnatchShot on 01/01/25.
//

import SwiftUI

struct FilterSelectionView: View {
    @Binding var selectedPreset: FilterPreset?
    @Binding var isPresented: Bool
    let camera: CameraService
    let previewImage: UIImage?

    @State private var presetManager = FilterPresetManager.shared
    @State private var selectedCategory: String = "Film"
    @State private var searchText: String = ""
    @State private var previewThumbnails: [String: UIImage] = [:]

    private var categories: [String] {
        Array(Set(presetManager.presets.map { $0.category })).sorted()
    }

    private var filteredPresets: [FilterPreset] {
        let categoryPresets = presetManager.presets.filter { $0.category == selectedCategory }
        if searchText.isEmpty {
            return categoryPresets
        } else {
            return categoryPresets.filter { preset in
                preset.name.localizedCaseInsensitiveContains(searchText) ||
                preset.source.localizedCaseInsensitiveContains(searchText) ||
                preset.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search filters...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)

                // Filter Grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        // None option
                        FilterThumbnailView(
                            preset: nil,
                            previewImage: previewImage,
                            isSelected: selectedPreset == nil,
                            onTap: {
                                selectedPreset = nil
                                camera.setPreset(nil)
                            }
                        )

                        // Preset options
                        ForEach(filteredPresets) { preset in
                            FilterThumbnailView(
                                preset: preset,
                                previewImage: previewThumbnails[preset.id] ?? previewImage,
                                isSelected: selectedPreset?.id == preset.id,
                                onTap: {
                                    selectedPreset = preset
                                    camera.setPreset(preset)

                                    // Generate preview thumbnail if not cached
                                    if previewThumbnails[preset.id] == nil {
                                        generatePreviewThumbnail(for: preset)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Filters")
            .navigationBarItems(
                trailing: Button("Done") {
                    isPresented = false
                }
            )
        }
        .onAppear {
            generateInitialPreviews()
        }
    }

    private func generateInitialPreviews() {
        // Generate thumbnails for visible presets in background
        DispatchQueue.global(qos: .userInitiated).async {
            for preset in filteredPresets.prefix(9) { // First 9 visible
                if previewThumbnails[preset.id] == nil {
                    generatePreviewThumbnail(for: preset)
                }
            }
        }
    }

    private func generatePreviewThumbnail(for preset: FilterPreset) {
        guard let image = previewImage else { return }

        // Create a smaller version for thumbnail
        let thumbnailSize = CGSize(width: 120, height: 120)
        UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let thumbnail = thumbnail {
            let processor = ModularFilterProcessor()
            let filteredThumbnail = processor.applyPreset(preset, to: thumbnail)

            DispatchQueue.main.async {
                previewThumbnails[preset.id] = filteredThumbnail
            }
        }
    }
}

struct FilterThumbnailView: View {
    let preset: FilterPreset?
    let previewImage: UIImage?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Preview Image
                if let image = previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: preset == nil ? "xmark" : "photo")
                                .foregroundColor(.gray)
                        )
                }

                // Selection Indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: 80, height: 80)
                }
            }
            .onTapGesture(perform: onTap)

            // Filter Name
            Text(preset?.name ?? "None")
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .primary)
                .lineLimit(1)
                .frame(width: 80)
        }
    }
}

// MARK: - Filter Detail View
struct FilterDetailView: View {
    let preset: FilterPreset
    @Binding var isPresented: Bool
    @Binding var selectedPreset: FilterPreset?
    let camera: CameraService

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    if let image = camera.lastPhoto {
                        let processor = ModularFilterProcessor()
                        let preview = processor.applyPreset(preset, to: image)

                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }

                    // Filter Info
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(preset.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            Text(preset.category)
                                .font(.caption)
                                .padding(6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }

                        Text(preset.description)
                            .font(.body)
                            .foregroundColor(.secondary)

                        // Filter Parameters
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Filter Parameters")
                                .font(.headline)

                            ParameterRow(label: "Temperature", value: preset.modules.temperature, unit: "°")
                            ParameterRow(label: "Tint", value: preset.modules.tint, unit: "")
                            ParameterRow(label: "Exposure", value: preset.modules.exposure, unit: "EV")
                            ParameterRow(label: "Contrast", value: preset.modules.contrast, unit: "")
                            ParameterRow(label: "Saturation", value: preset.modules.saturation, unit: "")

                            if preset.modules.grain > 0 {
                                ParameterRow(label: "Grain", value: preset.modules.grain, unit: "")
                            }
                            if preset.modules.vignette > 0 {
                                ParameterRow(label: "Vignette", value: preset.modules.vignette, unit: "")
                            }
                            if preset.modules.halation > 0 {
                                ParameterRow(label: "Halation", value: preset.modules.halation, unit: "")
                            }

                            if let lut = preset.modules.lut {
                                HStack {
                                    Text("LUT")
                                    Spacer()
                                    Text(lut)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Filter Details")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Apply") {
                    selectedPreset = preset
                    camera.setPreset(preset)
                    isPresented = false
                }
                .fontWeight(.semibold)
            )
        }
    }
}

struct ParameterRow: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.2f", value) + unit)
                .foregroundColor(.secondary)
        }
        .font(.subheadline)
    }
}

// MARK: - Preview Provider
struct FilterSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleImage = UIImage(systemName: "photo")!
        FilterSelectionView(
            selectedPreset: .constant(nil),
            isPresented: .constant(true),
            camera: CameraService(),
            previewImage: sampleImage
        )
    }
}
