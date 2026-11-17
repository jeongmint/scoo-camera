import Foundation

/// Seoul's 25 districts (자치구). In the test build the district a user starts in decides which friend they are likely to get.
enum SeoulDistrict: String, CaseIterable, Identifiable, Codable {
    case jongno = "종로구", jung = "중구", yongsan = "용산구", seongdong = "성동구", gwangjin = "광진구"
    case dongdaemun = "동대문구", jungnang = "중랑구", seongbuk = "성북구", gangbuk = "강북구", dobong = "도봉구"
    case nowon = "노원구", eunpyeong = "은평구", seodaemun = "서대문구", mapo = "마포구", yangcheon = "양천구"
    case gangseo = "강서구", guro = "구로구", geumcheon = "금천구", yeongdeungpo = "영등포구", dongjak = "동작구"
    case gwanak = "관악구", seocho = "서초구", gangnam = "강남구", songpa = "송파구", gangdong = "강동구"

    var id: String { rawValue }

    /// English spelling used when the geocoder answers in English.
    var english: String {
        switch self {
        case .jongno: "Jongno-gu"
        case .jung: "Jung-gu"
        case .yongsan: "Yongsan-gu"
        case .seongdong: "Seongdong-gu"
        case .gwangjin: "Gwangjin-gu"
        case .dongdaemun: "Dongdaemun-gu"
        case .jungnang: "Jungnang-gu"
        case .seongbuk: "Seongbuk-gu"
        case .gangbuk: "Gangbuk-gu"
        case .dobong: "Dobong-gu"
        case .nowon: "Nowon-gu"
        case .eunpyeong: "Eunpyeong-gu"
        case .seodaemun: "Seodaemun-gu"
        case .mapo: "Mapo-gu"
        case .yangcheon: "Yangcheon-gu"
        case .gangseo: "Gangseo-gu"
        case .guro: "Guro-gu"
        case .geumcheon: "Geumcheon-gu"
        case .yeongdeungpo: "Yeongdeungpo-gu"
        case .dongjak: "Dongjak-gu"
        case .gwanak: "Gwanak-gu"
        case .seocho: "Seocho-gu"
        case .gangnam: "Gangnam-gu"
        case .songpa: "Songpa-gu"
        case .gangdong: "Gangdong-gu"
        }
    }

    /// The friend that lives in this district. First draft of the split — edit freely:
    /// 모리 = 산과 하천이 가까운 동네, 쿠르 = 멋진 도심, 귀요 = 귀여운 골목, 냐모 = 먹거리 동네.
    var primary: Companion {
        switch self {
        case .gangbuk, .dobong, .nowon, .eunpyeong, .gwanak, .gangdong, .jungnang: .mori
        case .gangnam, .seocho, .songpa, .yongsan, .yeongdeungpo, .dongjak: .kuru
        case .mapo, .seodaemun, .seongdong, .gwangjin, .yangcheon, .gangseo: .gwiyo
        case .jongno, .jung, .seongbuk, .dongdaemun, .guro, .geumcheon: .nyamo
        }
    }

    /// Finds a district in the strings a reverse geocoder returns (city, sub-locality, address name, …).
    /// A district counts only with its "구" suffix, so street names like "강남대로" never match.
    static func match(in texts: [String]) -> SeoulDistrict? {
        for text in texts {
            let lowered = text.lowercased()
            if let found = allCases.first(where: { text.contains($0.rawValue) || lowered.contains($0.english.lowercased()) }) {
                return found
            }
        }
        return nil
    }
}

extension Companion {
    /// How often a district's own friend shows up; the rest of the draws go to the other regular friends.
    static let hometownChance = 0.7

    /// Location-weighted draw: usually the district's own friend, sometimes one of the others.
    static func assign<G: RandomNumberGenerator>(in district: SeoulDistrict, using generator: inout G) -> Companion {
        if Double.random(in: 0..<1, using: &generator) < hometownChance { return district.primary }
        return regulars.filter { $0 != district.primary }.randomElement(using: &generator) ?? district.primary
    }
}

extension SeoulDistrict {
    /// The local character met on the first photo in this district (동네 탐험). First draft — edit freely.
    /// Five districts have none; there a not-yet-met character turns up instead.
    var special: Species? {
        let id: String? = switch self {
        case .dobong: "huu"           // 도봉산 부엉이
        case .gwangjin: "chiko"       // 어린이대공원
        case .nowon: "dochi"
        case .gwanak: "luna"          // 낙성대, 별이 떨어진 곳
        case .yongsan: "toto"
        case .gangseo: "sunny"
        case .gangdong: "suri"
        case .seocho: "mellu"         // 양재 꽃·과일
        case .jung: "riru"            // 시장 과일
        case .jongno: "popo"          // 인사동 찻집
        case .geumcheon: "tangerine"
        case .songpa: "baseball"      // 잠실야구장
        case .seongdong: "otter"      // 중랑천 수달
        case .dongdaemun: "yarn"      // 동대문 원단시장
        case .seongbuk: "tori"
        case .eunpyeong: "mupu"       // 북한산 너구리
        case .mapo: "deogi"           // 연남동 산책길
        case .jungnang: "hechi"
        case .yangcheon: "sia"
        case .gangbuk: "dia"
        case .seodaemun, .guro, .yeongdeungpo, .dongjak, .gangnam: nil
        }
        return id.flatMap(Species.find)
    }
}
