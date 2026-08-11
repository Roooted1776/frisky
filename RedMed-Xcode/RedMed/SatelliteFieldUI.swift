import SwiftUI
import CoreLocation

/// Find Help satellite UX: Bluetooth terminal banner, UTF-8 byte budget on the
/// note field, and “Pending Satellite Transmission” queue rows (no spinner-only wait).
struct SatelliteFieldCard: View {
    @ObservedObject var pipeline: SatelliteOutboundPipeline
    var location: CLLocation?

    @State private var note = ""
    @State private var includeGPS = true

    private var composed: String {
        var parts: [String] = []
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { parts.append(trimmed) }
        if includeGPS, let loc = location {
            parts.append(String(format: "GPS %.5f,%.5f", loc.coordinate.latitude, loc.coordinate.longitude))
        }
        return parts.joined(separator: " | ")
    }

    private var byteCount: Int { SatellitePayloadSizer.utf8ByteCount(composed) }
    private var overSoft: Bool { SatellitePayloadSizer.isOverSoftLimit(composed) }
    private var overHard: Bool { SatellitePayloadSizer.isOverHardLimit(composed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 15))
                    .foregroundColor(.redmedAccent)
                    .frame(width: 28, height: 28)
                    .background(Color.redmedAccent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Satellite terminal")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.redmedDark)
                    Text("Phone → Bluetooth terminal → uplink. Not Apple SOS. Not RedMed cloud.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SatelliteConnectionBanner(
                isLinked: pipeline.isLinked,
                label: pipeline.linkLabel,
                usesSimulation: pipeline.usesSimulation,
                onToggleSimulated: { pipeline.toggleSimulatedLink() }
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Field note")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.redmedMuted)
                TextEditor(text: $note)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(.redmedDark)
                    .frame(minHeight: 72, maxHeight: 120)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.redmedDivider, lineWidth: 1))

                SatelliteByteCounter(byteCount: byteCount, overSoft: overSoft, overHard: overHard)

                Toggle(isOn: $includeGPS) {
                    Text("Append live GPS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.redmedDark)
                }
                .tint(.redmedAccent)
                .disabled(location == nil)

                if overSoft && !overHard {
                    Text(AppConfig.Satellite.softWarnCopy)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                }
                if overHard {
                    Text(AppConfig.Satellite.hardRefuseCopy)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                }
            }

            Button {
                let ok = pipeline.enqueueClinicianNote(composed)
                if ok { note = "" }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                    Text(pipeline.pendingCount > 0 ? "Queue another satellite note" : "Queue satellite note")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: overHard
                            ? [Color.redmedMuted, Color.redmedMuted]
                            : [Color(red: 1, green: 0.447, blue: 0.537), .redmedAccent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
            }
            .disabled(overHard || composed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let err = pipeline.lastError, !err.isEmpty {
                Text(err)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.redmedAccent)
            }

            if !pipeline.queue.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Queue")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.redmedMuted)
                    ForEach(pipeline.queue.prefix(5)) { item in
                        SatelliteQueueRow(item: item)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.redmedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.redmedDivider, lineWidth: 1))
    }
}

struct SatelliteConnectionBanner: View {
    let isLinked: Bool
    let label: String
    let usesSimulation: Bool
    let onToggleSimulated: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(isLinked ? Color.green.opacity(0.85) : Color.redmedMuted.opacity(0.45))
                .frame(width: 10, height: 10)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(isLinked ? "Terminal linked" : "Terminal not linked")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.redmedDark)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if usesSimulation {
                Button(isLinked ? "Disconnect" : "Connect") {
                    onToggleSimulated()
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isLinked ? .redmedDark : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isLinked ? Color.white.opacity(0.9) : Color.redmedAccent)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.redmedDivider, lineWidth: isLinked ? 1 : 0))
            }
        }
        .padding(10)
        .background(Color.redmedAccent.opacity(isLinked ? 0.06 : 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SatelliteByteCounter: View {
    let byteCount: Int
    let overSoft: Bool
    let overHard: Bool

    private var color: Color {
        if overHard { return .redmedAccent }
        if overSoft { return .orange }
        return .redmedMuted
    }

    var body: some View {
        HStack {
            Text("\(byteCount) / \(AppConfig.Satellite.hardPayloadBytes) bytes")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Spacer()
            Text("soft \(AppConfig.Satellite.softPayloadBytes) · hard \(AppConfig.Satellite.hardPayloadBytes)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.redmedMuted)
        }
    }
}

struct SatelliteQueueRow: View {
    let item: SatelliteQueueItem

    private var statusColor: Color {
        switch item.status {
        case .pendingTransmission: return .orange
        case .sent: return .green
        case .failed: return .redmedAccent
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if item.status == .pendingTransmission {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(statusColor)
                    .padding(.top, 2)
            } else {
                Image(systemName: item.status == .sent ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(statusColor)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.status.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(statusColor)
                Text(item.detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.redmedMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
