import SwiftUI

struct DocumentCard: View {
    let document: HealthDocument

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            info
            Spacer()
            ProcessingStatusBadge(status: document.processingStatus)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Double tap to view")
    }

    private var documentIcon: String {
        switch document.documentType {
        case .labResult:         return "flask"
        case .radiology:         return "waveform.path.ecg"
        case .dischargeSummary:  return "list.clipboard"
        case .clinicalNote:      return "note.text"
        case .prescription:      return "pills"
        case .insurance:         return "shield"
        case .unknown:           return "doc.text"
        }
    }

    private var thumbnail: some View {
        Group {
            if let data = document.thumbnailData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: documentIcon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: 56, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(Color.lavendorCard, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    private var cardAccessibilityLabel: String {
        var parts = ["\(document.documentType.displayName), \(document.filename)"]
        parts.append("Uploaded \(document.uploadedAt.formatted(date: .abbreviated, time: .omitted))")
        switch document.processingStatus {
        case .processing: parts.append("Analysis in progress")
        case .failed:     parts.append("Analysis failed")
        case .complete:   break
        }
        return parts.joined(separator: ". ")
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(document.filename)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(document.documentType.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.lavendorTint, in: Capsule())
                    .foregroundStyle(Color.accentColor)

                Text(document.uploadedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

