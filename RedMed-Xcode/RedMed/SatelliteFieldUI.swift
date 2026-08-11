import SwiftUI
import CoreLocation

/// Find Help satellite UX — same Theme.swift palette + InfoCard type scale as the rest of Help.
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
                Text("Satellite Terminal")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.redmedDark)
            }

            Text("Phone → Bluetooth terminal → uplink. Not Apple SOS. Not RedMed cloud.")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)
                .lineSpacing(3)

            SatelliteConnectionBanner(
                isLinked: pipeline.isLinked,
                label: pipeline.linkLabel,
                usesSimulation: pipeline.usesSimulation,
                onToggleSimulated: { pipeline.toggleSimulatedLink() }
            )

            Text("Field note")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)

            TextEditor(text: $note)
                .font(.system(size: 11, weight: .semibold))
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.redmedDark)
            }
            .tint(.redmedAccent)
            .disabled(location == nil)

            if overSoft && !overHard {
                Text(AppConfig.Satellite.softWarnCopy)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .lineSpacing(3)
            }
            if overHard {
                Text(AppConfig.Satellite.hardRefuseCopy)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .lineSpacing(3)
            }

            Button {
                let ok = pipeline.enqueueClinicianNote(composed)
                if ok { note = "" }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                    Text(pipeline.pendingCount > 0 ? "Queue another satellite note" : "Queue satellite note")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(overHard ? Color.redmedMuted : Color.redmedDark)
                .clipShape(Capsule())
            }
            .disabled(overHard || composed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let err = pipeline.lastError, !err.isEmpty {
                Text(err)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .lineSpacing(3)
            }

            if !pipeline.queue.isEmpty {
                Text("Queue")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.redmedMuted)
                ForEach(pipeline.queue.prefix(5)) { item in
                    SatelliteQueueRow(item: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(isLinked ? Color.redmedAccent : Color.redmedMuted.opacity(0.45))
                .frame(width: 10, height: 10)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(isLinked ? "Terminal linked" : "Terminal not linked")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.redmedDark)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.redmedMuted)
                    .lineSpacing(3)
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
                .padding(.vertical, 8)
                .background(isLinked ? Color.white.opacity(0.9) : Color.redmedAccent)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.redmedDivider, lineWidth: isLinked ? 1 : 0))
            }
        }
        .padding(10)
        .background(Color.redmedAccent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SatelliteByteCounter: View {
    let byteCount: Int
    let overSoft: Bool
    let overHard: Bool

    private var color: Color {
        (overSoft || overHard) ? .redmedAccent : .redmedMuted
    }

    var body: some View {
        HStack {
            Text("\(byteCount) / \(AppConfig.Satellite.hardPayloadBytes) bytes")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Spacer()
            Text("soft \(AppConfig.Satellite.softPayloadBytes) · hard \(AppConfig.Satellite.hardPayloadBytes)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.redmedMuted)
        }
    }
}

struct SatelliteQueueRow: View {
    let item: SatelliteQueueItem

    private var statusColor: Color {
        switch item.status {
        case .pendingTransmission: return .redmedMuted
        case .sent: return .redmedDark
        case .failed: return .redmedAccent
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: {
                switch item.status {
                case .pendingTransmission: return "clock.fill"
                case .sent: return "checkmark.circle.fill"
                case .failed: return "xmark.circle.fill"
                }
            }())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(statusColor)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.status.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(statusColor)
                Text(item.detail)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.redmedMuted)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
    }
}
