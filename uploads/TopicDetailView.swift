import SwiftUI

extension AidTopic: Identifiable {}

struct TopicDetailView: View {
    let topic: AidTopic
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // RECOGNIZE
                    Text("Recognize")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
                        .kerning(0.5)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)
                        .padding(.top, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(topic.symptoms.enumerated()), id: \.offset) { i, sym in
                            Text(sym)
                                .font(.system(size: 15))
                                .foregroundColor(.redmedDark)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 13)
                            if i < topic.symptoms.count - 1 {
                                Divider().overlay(Color.black.opacity(0.06))
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 22)

                    // WHAT TO DO
                    Text("What to do")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.42, green: 0.43, blue: 0.48))
                        .kerning(0.5)
                        .textCase(.uppercase)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        ForEach(Array(topic.care.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.redmedAccent)
                                    .padding(.top, 4)
                                Text(step)
                                    .font(.system(size: 15))
                                    .foregroundColor(.redmedDark)
                                    .lineSpacing(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            if i < topic.care.count - 1 {
                                Divider().overlay(Color.black.opacity(0.06))
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 24)

                    PrimaryButton(title: "Call 911") {
                        if let url = URL(string: "tel://911") { UIApplication.shared.open(url) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color(red: 0.949, green: 0.949, blue: 0.969))
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Aid")
                        }
                        .foregroundColor(.redmedAccent)
                    }
                }
            }
        }
    }
}
