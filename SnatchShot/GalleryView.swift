//
//  GalleryView.swift
//  SnatchShot
//

import SwiftUI

// MARK: - Models
struct GalleryPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let type: PhotoType
    let timestamp: Date

    var thumbnail: UIImage {
        let size = CGSize(width: 120, height: 120)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            self.image.draw(in: rect)
        }
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ?
                        Color(red: 0.600, green: 0.545, blue: 0.941).opacity(0.8) :
                        Color.white.opacity(0.1)
                )
                .cornerRadius(20)
        }
    }
}

// MARK: - Image Detail Overlay
struct ImageDetailOverlay: View {
    let image: UIImage
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button("Close") {
                    onDismiss()
                }
                .foregroundColor(.white)
                .padding()

                Spacer()

                Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
                    .padding(.trailing)
            }

            Spacer()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Spacer()
        }
    }
}

// MARK: - Main Gallery View
struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: PhotoType = .all
    @State private var photos: [GalleryPhoto] = []
    @State private var selectedImage: UIImage? = nil
    @State private var showOverlay = false
    @State private var isLoading = false

    let preselectedImage: UIImage?

    init(preselectedImage: UIImage? = nil) {
        self.preselectedImage = preselectedImage
    }

    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]

    private var filteredPhotos: [GalleryPhoto] {
        switch selectedFilter {
        case .all: return photos
        case .original: return photos.filter { $0.type == .original }
        case .generated: return photos.filter { $0.type == .generated }
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.075, green: 0.082, blue: 0.102)
                .edgesIgnoringSafeArea(.all)

            // Main content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "chevron.left")
                                .foregroundColor(.primary)
                        }
                    }

                    Spacer()

                    Text("Gallery")
                        .font(.system(size: 20, weight: .bold))

                    Spacer()

                    Button(action: { loadPhotos() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal)

                // Filters
                HStack(spacing: 15) {
                    FilterButton(title: "All", isSelected: selectedFilter == .all) {
                        selectedFilter = .all
                    }
                    FilterButton(title: "Original", isSelected: selectedFilter == .original) {
                        selectedFilter = .original
                    }
                    FilterButton(title: "Generated", isSelected: selectedFilter == .generated) {
                        selectedFilter = .generated
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                // Content
                if photos.isEmpty && !isLoading {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No photos yet")
                            .foregroundColor(.gray.opacity(0.7))
                        Text("Take some photos to see them here!")
                            .foregroundColor(.gray.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 1) {
                            ForEach(filteredPhotos) { photo in
                                Button(action: {
                                    selectedImage = photo.image
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showOverlay = true
                                    }
                                }) {
                                    Image(uiImage: photo.thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: UIScreen.main.bounds.width / 3)
                                        .clipped()
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(1)
                    }
                }
            }
        }
        .overlay(
            Group {
                if showOverlay, let image = selectedImage {
                    ZStack {
                        Color.black
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showOverlay = false
                                }
                            }

                        ImageDetailOverlay(image: image) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showOverlay = false
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
        )
        .onAppear {
            loadPhotos()
            if let preselectedImage = preselectedImage {
                selectedImage = preselectedImage
                showOverlay = true
            }
        }
    }

    private func loadPhotos() {
        isLoading = true

        Task {
            let cachedPhotos = ImageCacheService.shared.getAllCachedPhotos()

            let galleryPhotos = cachedPhotos.compactMap { cachedPhoto -> GalleryPhoto? in
                guard let image = cachedPhoto.getImage() else {
                    return nil
                }
                // iOS handles image orientation automatically
                return GalleryPhoto(
                    image: image,
                    type: cachedPhoto.type,
                    timestamp: cachedPhoto.timestamp
                )
            }

            await MainActor.run {
                photos = galleryPhotos.sorted { $0.timestamp > $1.timestamp }
                isLoading = false
            }
        }
    }
}

#Preview {
    GalleryView()
}