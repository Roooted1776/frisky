import SwiftUI

/// Owner-facing "how it works" — renders `ios/claude/DesignPageCopy` pages 1–7.
struct HowItWorksView: View {
    @Environment(\.layoutMetrics) private var layout
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: layout.spaceLG) {
                    page1Hero
                    page2Problem
                    page3Solution
                    page4Comparison
                    page5Privacy
                    page6Product
                    page7Market
                }
                .padding(layout.screenPad)
                .padding(.bottom, layout.screenBottomLarge)
            }
            .screenAtmosphere()
            .navigationTitle("Help & About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .tint(AppTheme.accent)
    }

    // MARK: - Page 1 — brand

    private var page1Hero: some View {
        VStack(alignment: .leading, spacing: layout.spaceMD) {
            SectionEyebrow(text: DesignPageCopy.Page1.eyebrow)
            BrandMark(size: .hero, showTagline: false)
            Text(DesignPageCopy.Page1.tagline)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            Text(DesignPageCopy.Page1.lead)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }

    // MARK: - Page 2 — problem

    private var page2Problem: some View {
        VStack(alignment: .leading, spacing: layout.spaceMD) {
            SectionEyebrow(text: DesignPageCopy.Page2.eyebrow)
            Text(DesignPageCopy.Page2.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            VStack(alignment: .leading, spacing: layout.spaceSM) {
                ForEach(DesignPageCopy.Page2.bullets, id: \.self) { point in
                    bulletRow(point)
                }
            }
        }
        .padding(layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }

    // MARK: - Page 3 — solution

    private var page3Solution: some View {
        VStack(alignment: .leading, spacing: layout.spaceMD) {
            SectionEyebrow(text: DesignPageCopy.Page3.eyebrow)
            Text(DesignPageCopy.Page3.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text(DesignPageCopy.Page3.lead)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(DesignPageCopy.Page3.frictionLine)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text(DesignPageCopy.Page3.detail)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: layout.spaceMD) {
                ForEach(DesignPageCopy.Page3.flowSteps) { step in
                    VStack(alignment: .leading, spacing: layout.spaceXS) {
                        Text(step.label.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(AppTheme.muted)
                        Text(step.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(step.detail)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(layout.spaceMD)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.pageBg)
                    .clipShape(RoundedRectangle(cornerRadius: layout.cardRadius, style: .continuous))
                }
            }
        }
        .padding(layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }

    // MARK: - Page 4 — comparison

    private var page4Comparison: some View {
        VStack(alignment: .leading, spacing: layout.spaceMD) {
            SectionEyebrow(text: DesignPageCopy.Page4.eyebrow)
            Text(DesignPageCopy.Page4.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            comparisonTable

            Text(DesignPagePlacement.androidReaderNote)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            comparisonHeader
            ForEach(Array(DesignPageCopy.Page4.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Rectangle().fill(AppTheme.line).frame(height: 1)
                }
                comparisonDataRow(row)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: layout.chipRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.chipRadius, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private var comparisonHeader: some View {
        let cols = DesignPageCopy.Page4.columns
        return HStack(spacing: layout.s(4)) {
            Text("Feature")
                .frame(maxWidth: .infinity, alignment: .leading)
            compareHeaderCell(cols.0, accent: true)
            compareHeaderCell(cols.1)
            compareHeaderCell(cols.2)
            compareHeaderCell(cols.3)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(AppTheme.muted)
        .padding(.horizontal, layout.spaceSM)
        .padding(.vertical, layout.spaceMD)
        .background(AppTheme.pageBg)
    }

    private func compareHeaderCell(_ title: String, accent: Bool = false) -> some View {
        Text(title)
            .frame(width: layout.s(44))
            .multilineTextAlignment(.center)
            .foregroundStyle(accent ? AppTheme.accent : AppTheme.muted)
    }

    private func comparisonDataRow(_ row: DesignPageCopy.CompareRow) -> some View {
        HStack(spacing: layout.s(4)) {
            Text(row.feature)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            compareCheck(row.redMed, accent: true)
            compareCheck(row.qrBand)
            compareCheck(row.appleHealth)
            compareCheck(row.walletID)
        }
        .padding(.horizontal, layout.spaceSM)
        .padding(.vertical, layout.spaceMD)
    }

    private func compareCheck(_ yes: Bool, accent: Bool = false) -> some View {
        Image(systemName: yes ? "checkmark" : "xmark")
            .font(.caption2.weight(.bold))
            .foregroundStyle(yes ? (accent ? AppTheme.accent : AppTheme.ok) : AppTheme.muted.opacity(0.45))
            .frame(width: layout.s(44))
    }

    // MARK: - Page 5 — privacy

    private var page5Privacy: some View {
        VStack(alignment: .leading, spacing: layout.spaceMD) {
            SectionEyebrow(text: DesignPageCopy.Page5.eyebrow)
            Text(DesignPageCopy.Page5.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            VStack(alignment: .leading, spacing: layout.spaceSM) {
                ForEach(DesignPageCopy.Page5.bullets, id: \.self) { point in
                    bulletRow(point)
                }
            }
        }
        .padding(layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }

    // MARK: - Page 6 — product model

    private var page6Product: some View {
        VStack(alignment: .leading, spacing: layout.spaceMD) {
            SectionEyebrow(text: DesignPageCopy.Page6.eyebrow)
            Text(DesignPageCopy.Page6.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: layout.spaceMD
            ) {
                ForEach(DesignPageCopy.Page6.valueCards) { card in
                    VStack(alignment: .leading, spacing: layout.spaceXS) {
                        Text(card.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(card.body)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(layout.spaceMD)
                    .frame(maxWidth: .infinity, minHeight: layout.s(100), alignment: .topLeading)
                    .background(AppTheme.pageBg)
                    .clipShape(RoundedRectangle(cornerRadius: layout.chipRadius, style: .continuous))
                }
            }
        }
        .padding(layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }

    // MARK: - Page 7 — market

    private var page7Market: some View {
        VStack(alignment: .leading, spacing: layout.spaceMD) {
            SectionEyebrow(text: DesignPageCopy.Page7.eyebrow)
            Text(DesignPageCopy.Page7.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            VStack(spacing: layout.spaceMD) {
                ForEach(DesignPageCopy.Page7.stats) { stat in
                    VStack(alignment: .leading, spacing: layout.spaceXS) {
                        Text(stat.value)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                        Text(stat.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(stat.detail)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }

    // MARK: - Shared

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: layout.s(8)) {
            Circle()
                .fill(AppTheme.accent)
                .frame(width: layout.bulletDot, height: layout.bulletDot)
                .padding(.top, layout.s(6))
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    HowItWorksView()
        .withLayoutMetrics()
}
