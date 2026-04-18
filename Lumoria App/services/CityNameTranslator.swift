//
//  CityNameTranslator.swift
//  Lumoria App
//
//  Best-effort Latin → CJK translator for city names. Backed by a static
//  table of major Shinkansen-served destinations plus a few common
//  international cities. Designed as a *suggestion* — every kanji field
//  the user sees remains editable, so missing entries simply mean the
//  user types the kanji themselves.
//

import Foundation

enum CityNameTranslator {

    /// Returns a kanji / kana suggestion for the given Latin city name,
    /// or `nil` if no mapping is known. Match is case-insensitive and
    /// trims whitespace; alternate spellings are folded onto a single
    /// canonical entry (e.g. "Kyoto" / "Kyōto" both map to 京都).
    static func kanji(for latinName: String) -> String? {
        let key = canonicalKey(latinName)
        return table[key]
    }

    // MARK: - Lookup table
    //
    // Cover the cities Shinkansen / JR services actually stop at, plus
    // a small set of major international destinations users may pair
    // with a stylised Japanese-themed ticket. Add entries here over
    // time — the translator falls back to the user's input when a key
    // is missing.

    private static let table: [String: String] = [
        // Honshu & Kyushu (Tōkaidō / Sanyō / Kyūshū lines)
        "tokyo":       "東京",
        "shinagawa":   "品川",
        "shinyokohama":"新横浜",
        "yokohama":    "横浜",
        "odawara":     "小田原",
        "atami":       "熱海",
        "mishima":     "三島",
        "shizuoka":    "静岡",
        "hamamatsu":   "浜松",
        "toyohashi":   "豊橋",
        "nagoya":      "名古屋",
        "gifu":        "岐阜",
        "maibara":     "米原",
        "kyoto":       "京都",
        "osaka":       "大阪",
        "shinosaka":   "新大阪",
        "shinkobe":    "新神戸",
        "kobe":        "神戸",
        "himeji":      "姫路",
        "okayama":     "岡山",
        "hiroshima":   "広島",
        "shinyamaguchi":"新山口",
        "kokura":      "小倉",
        "hakata":      "博多",
        "fukuoka":     "福岡",
        "kumamoto":    "熊本",
        "kagoshima":   "鹿児島",
        "kagoshimachuo":"鹿児島中央",

        // Tōhoku / Hokkaidō / Jōetsu / Hokuriku lines
        "ueno":        "上野",
        "omiya":       "大宮",
        "utsunomiya":  "宇都宮",
        "fukushima":   "福島",
        "sendai":      "仙台",
        "morioka":     "盛岡",
        "shinaomori":  "新青森",
        "aomori":      "青森",
        "shinhakodate":"新函館北斗",
        "hakodate":    "函館",
        "sapporo":     "札幌",
        "niigata":     "新潟",
        "nagano":      "長野",
        "toyama":      "富山",
        "kanazawa":    "金沢",
        "fukui":       "福井",
        "tsuruga":     "敦賀",

        // Other commonly used destinations
        "nara":        "奈良",
        "nikko":       "日光",
        "nagasaki":    "長崎",
        "yokosuka":    "横須賀",

        // Major international cities (katakana)
        "paris":       "パリ",
        "london":      "ロンドン",
        "newyork":     "ニューヨーク",
        "losangeles":  "ロサンゼルス",
        "sanfrancisco":"サンフランシスコ",
        "chicago":     "シカゴ",
        "berlin":      "ベルリン",
        "rome":        "ローマ",
        "madrid":      "マドリード",
        "barcelona":   "バルセロナ",
        "amsterdam":   "アムステルダム",
        "vienna":      "ウィーン",
        "prague":      "プラハ",
        "milan":       "ミラノ",
        "venice":      "ベネチア",
        "florence":    "フィレンツェ",
        "lisbon":      "リスボン",
        "seoul":       "ソウル",
        "busan":       "釜山",
        "beijing":     "北京",
        "shanghai":    "上海",
        "hongkong":    "香港",
        "taipei":      "台北",
        "singapore":   "シンガポール",
        "bangkok":     "バンコク",
        "sydney":      "シドニー",
        "melbourne":   "メルボルン",
        "dubai":       "ドバイ",
        "istanbul":    "イスタンブール",
    ]

    // MARK: - Key normalisation

    /// Lowercases, strips diacritics, and removes spaces / hyphens /
    /// apostrophes so "New York", "new-york" and "newyork" all match.
    private static func canonicalKey(_ raw: String) -> String {
        let folded = raw
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "en_US"))
            .lowercased()
        return folded.unicodeScalars
            .filter { CharacterSet.lowercaseLetters.contains($0) || CharacterSet.decimalDigits.contains($0) }
            .reduce(into: "") { $0.append(Character($1)) }
    }
}
