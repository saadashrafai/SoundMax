import Foundation

// MARK: - AutoEQ Integration
// Fetches headphone correction curves from the AutoEQ project
// https://github.com/jaakkopasanen/AutoEq

class AutoEQManager: ObservableObject {
    static let shared = AutoEQManager()

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchResults: [AutoEQHeadphone] = []

    // Our 10 fixed frequency bands
    static let targetFrequencies: [Double] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    // Popular headphones index (curated list for quick access)
    static let popularHeadphones: [AutoEQHeadphone] = [
        // Over-ear
        AutoEQHeadphone(name: "Sennheiser HD 600", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Sennheiser HD 650", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Sennheiser HD 800", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Sennheiser HD 800 S", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Beyerdynamic DT 770 Pro", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Beyerdynamic DT 880", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Beyerdynamic DT 990 Pro", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Audio-Technica ATH-M50x", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Sony WH-1000XM4", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Sony WH-1000XM5", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Bose QuietComfort 45", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "AKG K701", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "AKG K702", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "HiFiMAN Sundara", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "HiFiMAN HE400i 2020", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Focal Clear", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Meze 99 Classics", source: "oratory1990", type: "over-ear"),
        AutoEQHeadphone(name: "Philips SHP9500", source: "oratory1990", type: "over-ear"),

        // In-ear / IEMs
        AutoEQHeadphone(name: "Apple AirPods Pro", source: "oratory1990", type: "in-ear"),
        AutoEQHeadphone(name: "Apple AirPods Pro 2", source: "oratory1990", type: "in-ear"),
        AutoEQHeadphone(name: "Apple AirPods (3rd generation)", source: "oratory1990", type: "in-ear"),
        AutoEQHeadphone(name: "Sony WF-1000XM4", source: "oratory1990", type: "in-ear"),
        AutoEQHeadphone(name: "Samsung Galaxy Buds Pro", source: "oratory1990", type: "in-ear"),
        AutoEQHeadphone(name: "Shure SE215", source: "oratory1990", type: "in-ear"),
        AutoEQHeadphone(name: "Shure SE535", source: "oratory1990", type: "in-ear"),
        AutoEQHeadphone(name: "Moondrop Blessing 2", source: "crinacle", type: "in-ear"),
        AutoEQHeadphone(name: "Moondrop Starfield", source: "crinacle", type: "in-ear"),
        AutoEQHeadphone(name: "Moondrop Aria", source: "crinacle", type: "in-ear"),
        AutoEQHeadphone(name: "7Hz Timeless", source: "crinacle", type: "in-ear"),
        AutoEQHeadphone(name: "Etymotic ER2XR", source: "oratory1990", type: "in-ear"),
        AutoEQHeadphone(name: "Etymotic ER4XR", source: "oratory1990", type: "in-ear"),

        // On-ear
        AutoEQHeadphone(name: "Koss Porta Pro", source: "oratory1990", type: "on-ear"),
        AutoEQHeadphone(name: "Grado SR80e", source: "oratory1990", type: "on-ear"),
    ]

    // MARK: - Search

    func search(query: String) {
        let lowercaseQuery = query.lowercased()
        searchResults = Self.popularHeadphones.filter { headphone in
            headphone.name.lowercased().contains(lowercaseQuery)
        }
    }

    // MARK: - Fetch EQ Data

    func fetchEQ(for headphone: AutoEQHeadphone, completion: @escaping (Result<[Float], Error>) -> Void) {
        isLoading = true
        errorMessage = nil

        let urlString = headphone.graphicEQURL
        guard let url = URL(string: urlString) else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(.failure(AutoEQError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    return
                }

                guard let data = data, let content = String(data: data, encoding: .utf8) else {
                    self?.errorMessage = "Could not read response"
                    completion(.failure(AutoEQError.invalidResponse))
                    return
                }

                // Check for 404
                if content.contains("404") || content.contains("Not Found") {
                    self?.errorMessage = "EQ data not found for this headphone"
                    completion(.failure(AutoEQError.notFound))
                    return
                }

                // Parse the GraphicEQ format
                do {
                    let bands = try self?.parseGraphicEQ(content) ?? []
                    completion(.success(bands))
                } catch {
                    self?.errorMessage = "Could not parse EQ data"
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Parse GraphicEQ Format

    private func parseGraphicEQ(_ content: String) throws -> [Float] {
        // Format: GraphicEQ: 20 -3.5; 22 -3.5; 23 -3.4; ...
        guard let eqLine = content.components(separatedBy: "\n").first(where: { $0.hasPrefix("GraphicEQ:") }) else {
            throw AutoEQError.parseError
        }

        let dataString = eqLine.replacingOccurrences(of: "GraphicEQ:", with: "").trimmingCharacters(in: .whitespaces)
        let pairs = dataString.components(separatedBy: ";")

        var frequencyGainMap: [(Double, Double)] = []

        for pair in pairs {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            let components = trimmed.split(separator: " ")
            if components.count >= 2,
               let freq = Double(components[0]),
               let gain = Double(components[1]) {
                frequencyGainMap.append((freq, gain))
            }
        }

        guard !frequencyGainMap.isEmpty else {
            throw AutoEQError.parseError
        }

        // Interpolate to our 10 target frequencies
        return interpolateToTargetBands(frequencyGainMap)
    }

    // MARK: - Interpolation

    private func interpolateToTargetBands(_ data: [(Double, Double)]) -> [Float] {
        var result: [Float] = []

        for targetFreq in Self.targetFrequencies {
            // Find surrounding points for interpolation
            var lowerIndex = 0
            var upperIndex = data.count - 1

            for (i, point) in data.enumerated() {
                if point.0 <= targetFreq {
                    lowerIndex = i
                }
                if point.0 >= targetFreq && upperIndex == data.count - 1 {
                    upperIndex = i
                    break
                }
            }

            // Linear interpolation
            let lower = data[lowerIndex]
            let upper = data[upperIndex]

            let gain: Double
            if lower.0 == upper.0 {
                gain = lower.1
            } else {
                // Interpolate in log frequency space
                let logLower = log10(lower.0)
                let logUpper = log10(upper.0)
                let logTarget = log10(targetFreq)
                let t = (logTarget - logLower) / (logUpper - logLower)
                gain = lower.1 + t * (upper.1 - lower.1)
            }

            // Clamp to our ±12dB range
            result.append(Float(max(-12, min(12, gain))))
        }

        return result
    }
}

// MARK: - Models

struct AutoEQHeadphone: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let source: String  // oratory1990, crinacle, etc.
    let type: String    // over-ear, in-ear, on-ear

    var graphicEQURL: String {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return "https://raw.githubusercontent.com/jaakkopasanen/AutoEq/master/results/\(source)/\(type)/\(encodedName)/\(encodedName)%20GraphicEQ.txt"
    }

    var displayType: String {
        switch type {
        case "over-ear": return "Over-ear"
        case "in-ear": return "In-ear"
        case "on-ear": return "On-ear"
        default: return type.capitalized
        }
    }
}

// MARK: - Errors

enum AutoEQError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notFound
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .notFound: return "EQ data not found for this headphone"
        case .parseError: return "Could not parse EQ data"
        }
    }
}
