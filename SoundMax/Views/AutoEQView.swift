import SwiftUI

struct AutoEQView: View {
    @EnvironmentObject var eqModel: EQModel
    @StateObject private var autoEQManager = AutoEQManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedHeadphone: AutoEQHeadphone?
    @State private var showingConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            header

            searchField

            if autoEQManager.isLoading {
                loadingView
            } else if let error = autoEQManager.errorMessage {
                errorView(error)
            } else {
                headphoneList
            }

            Spacer()

            footer
        }
        .padding()
        .frame(width: 400, height: 450)
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "headphones")
                    .font(.title2)
                Text("AutoEQ Headphone Correction")
                    .font(.headline)
            }

            Text("Apply frequency response corrections for your headphones")
                .font(.caption)
                .foregroundColor(.secondary)

            Link("Powered by AutoEQ", destination: URL(string: "https://github.com/jaakkopasanen/AutoEq")!)
                .font(.caption2)
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search headphones...", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _, newValue in
                    if newValue.isEmpty {
                        autoEQManager.searchResults = AutoEQManager.popularHeadphones
                    } else {
                        autoEQManager.search(query: newValue)
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    autoEQManager.searchResults = AutoEQManager.popularHeadphones
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Fetching EQ data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.orange)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }

    private var headphoneList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                let headphones = searchText.isEmpty ? AutoEQManager.popularHeadphones : autoEQManager.searchResults

                if headphones.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No headphones found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Try a different search term")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(headphones) { headphone in
                        headphoneRow(headphone)
                    }
                }
            }
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func headphoneRow(_ headphone: AutoEQHeadphone) -> some View {
        Button {
            selectedHeadphone = headphone
            applyAutoEQ(headphone)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headphone.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Text(headphone.displayType)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if selectedHeadphone?.id == headphone.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedHeadphone?.id == headphone.id ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }

            Spacer()

            if selectedHeadphone != nil {
                Text("Applied: \(selectedHeadphone!.name)")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func applyAutoEQ(_ headphone: AutoEQHeadphone) {
        autoEQManager.fetchEQ(for: headphone) { result in
            switch result {
            case .success(let bands):
                eqModel.bands = bands
                eqModel.clearPresetSelection()
            case .failure:
                selectedHeadphone = nil
            }
        }
    }
}

#Preview {
    AutoEQView()
        .environmentObject(EQModel())
}
