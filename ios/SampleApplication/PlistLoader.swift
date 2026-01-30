import Foundation

class PlistLoader {
    static func loadSampleAppConfig() -> [String: String] {
        guard let path = Bundle.main.path(forResource: "SampleAppConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            print("⚠️ SampleAppConfig.plist não encontrado")
            return [:]
        }

        print("✓ SampleAppConfig.plist carregado com sucesso (\(dict.count) variáveis)")
        return dict
    }
}
