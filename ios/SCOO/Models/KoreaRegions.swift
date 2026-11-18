import Foundation

// 전국 시군구와 그곳에 사는 동네 친구. 배치를 바꿀 땐 맨 아래 표를 고쳐요.
// Nationwide 시군구 (17 시도, 229 시군구) and the friend who lives in each. A friend's rarity is how many
// places it lives in (Regions.homes).

/// 시도: the 8 provinces, Jeju, and the special and metropolitan cities.
enum Province: String, CaseIterable, Codable, Identifiable {
    case seoul = "서울특별시"
    case busan = "부산광역시"
    case daegu = "대구광역시"
    case incheon = "인천광역시"
    case gwangju = "광주광역시"
    case daejeon = "대전광역시"
    case ulsan = "울산광역시"
    case sejong = "세종특별자치시"
    case gyeonggi = "경기도"
    case gangwon = "강원특별자치도"
    case chungbuk = "충청북도"
    case chungnam = "충청남도"
    case jeonbuk = "전북특별자치도"
    case jeonnam = "전라남도"
    case gyeongbuk = "경상북도"
    case gyeongnam = "경상남도"
    case jeju = "제주특별자치도"

    var id: String { rawValue }

    /// "서울", "경기", "충북" …
    var short: String {
        switch self {
        case .seoul: return "서울"
        case .busan: return "부산"
        case .daegu: return "대구"
        case .incheon: return "인천"
        case .gwangju: return "광주"
        case .daejeon: return "대전"
        case .ulsan: return "울산"
        case .sejong: return "세종"
        case .gyeonggi: return "경기"
        case .gangwon: return "강원"
        case .chungbuk: return "충북"
        case .chungnam: return "충남"
        case .jeonbuk: return "전북"
        case .jeonnam: return "전남"
        case .gyeongbuk: return "경북"
        case .gyeongnam: return "경남"
        case .jeju: return "제주"
        }
    }

    /// Full names a geocoder may answer with, old ones included (강원도 → 강원특별자치도, 2023).
    var names: [String] {
        switch self {
        case .seoul: return ["서울특별시"]
        case .busan: return ["부산광역시"]
        case .daegu: return ["대구광역시"]
        case .incheon: return ["인천광역시"]
        case .gwangju: return ["광주광역시"]
        case .daejeon: return ["대전광역시"]
        case .ulsan: return ["울산광역시"]
        case .sejong: return ["세종특별자치시", "세종시"]
        case .gyeonggi: return ["경기도"]
        case .gangwon: return ["강원특별자치도", "강원도"]
        case .chungbuk: return ["충청북도"]
        case .chungnam: return ["충청남도"]
        case .jeonbuk: return ["전북특별자치도", "전라북도"]
        case .jeonnam: return ["전라남도"]
        case .gyeongbuk: return ["경상북도"]
        case .gyeongnam: return ["경상남도"]
        case .jeju: return ["제주특별자치도", "제주도"]
        }
    }
}

/// One 시군구 and its local friend.
struct Region: Hashable, Identifiable {
    let province: Province
    /// "마포구", "가평군", "수원시"
    let name: String
    /// The species that lives here (met on the first photo here).
    let friendID: String
    /// Why that friend lives here, shown when you meet it.
    let note: String

    /// Stable key, also what the app stores: "서울 마포구". 세종 is just "세종".
    var id: String { province == .sejong ? province.short : "\(province.short) \(name)" }
    var title: String { id }
    var friend: Species? { Species.find(friendID) }

    /// The camera friend a first launch here hands out (70%): nature, city, cute alleys or food,
    /// following the local friend's kind.
    var primary: Companion {
        switch friendID {
        case "mori", "huu", "mupu", "dochi", "chiko", "hechi", "otter": return .mori
        case "kuru", "toto", "luna", "sunny", "baseball": return .kuru
        case "gwiyo", "yarn", "popo", "tori", "deogi": return .gwiyo
        default: return .nyamo
        }
    }
}

extension Companion {
    /// How often the place's own camera friend shows up on first launch; the rest go to the other regular friends.
    static let hometownChance = 0.7

    /// Location-weighted draw: usually the place's own friend, sometimes one of the others.
    static func assign<G: RandomNumberGenerator>(in region: Region, using generator: inout G) -> Companion {
        if Double.random(in: 0..<1, using: &generator) < hometownChance { return region.primary }
        return regulars.filter { $0 != region.primary }.randomElement(using: &generator) ?? region.primary
    }
}

enum Regions {
    static let all: [Region] = table.flatMap { province, rows in
        rows.map { Region(province: province, name: $0.0, friendID: $0.1, note: $0.2) }
    }
    private static let byID: [String: Region] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func find(_ id: String) -> Region? { byID[id] }

    /// A stored value, including those saved before regions went nationwide (just "마포구", always Seoul).
    static func resolve(_ stored: String) -> Region? {
        if let region = byID[stored] { return region }
        return all.first { $0.province == .seoul && $0.name == stored }
    }

    static func of(_ province: Province) -> [Region] { all.filter { $0.province == province } }

    /// Where a species lives (its rarity is how many places).
    static func homes(of speciesID: String) -> [Region] { all.filter { $0.friendID == speciesID } }

    /// Finds the 시군구 in the strings a reverse geocoder returns (province, city, district, address …).
    static func match(in texts: [String]) -> Region? {
        let tokens = Set(texts.flatMap { $0.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init) })
        let province = Province.allCases.first { province in
            province.names.contains { name in tokens.contains(name) || texts.contains { $0.contains(name) } }
        }
        if let province {
            let candidates = of(province)
            if candidates.count == 1 { return candidates[0] }
            return candidates.first { tokens.contains($0.name) }
        }
        // no province in the answer: only a name that exists once in the country counts
        let found = all.filter { tokens.contains($0.name) }
        return found.count == 1 ? found[0] : nil
    }

    // MARK: The table (시도 → 시군구, friend, why)

    static let table: [(Province, [(String, String, String)])] = [
        (.seoul, [
            ("종로구", "popo", "인사동 찻집"),
            ("중구", "riru", "남대문·중부시장 과일"),
            ("용산구", "toto", "전쟁기념관·남산타워 하늘"),
            ("성동구", "otter", "중랑천 수달"),
            ("광진구", "chiko", "어린이대공원"),
            ("동대문구", "yarn", "동대문 원단시장"),
            ("중랑구", "hechi", "중랑천 습지"),
            ("성북구", "tori", "성북동 언덕"),
            ("강북구", "dia", "북한산 자락 과수"),
            ("도봉구", "huu", "도봉산 부엉이"),
            ("노원구", "dochi", "불암산"),
            ("은평구", "mupu", "북한산 너구리"),
            ("서대문구", "gwiyo", "신촌 골목"),
            ("마포구", "deogi", "연남동 산책길"),
            ("양천구", "sia", "목동 공원"),
            ("강서구", "sunny", "서울식물원 햇살"),
            ("구로구", "baseball", "고척돔"),
            ("금천구", "tangerine", "금천 시장"),
            ("영등포구", "kuru", "여의도 빌딩숲"),
            ("동작구", "mori", "현충원 숲"),
            ("관악구", "luna", "낙성대, 별이 떨어진 곳"),
            ("서초구", "mellu", "양재 꽃·과일"),
            ("강남구", "kuru", "멋진 도심"),
            ("송파구", "baseball", "잠실야구장"),
            ("강동구", "suri", "강동 텃밭"),
        ]),
        (.busan, [
            ("중구", "nyamo", "자갈치·국제시장 먹거리"),
            ("서구", "sunny", "송도 해수욕장 햇살"),
            ("동구", "gwiyo", "초량 이바구길 골목"),
            ("영도구", "otter", "태종대 바다"),
            ("부산진구", "kuru", "서면 도심"),
            ("동래구", "baseball", "사직야구장"),
            ("남구", "sunny", "오륙도 해돋이"),
            ("북구", "deogi", "화명 강변 산책길"),
            ("해운대구", "otter", "해운대 해수욕장"),
            ("사하구", "hechi", "을숙도 철새"),
            ("금정구", "huu", "금정산 숲"),
            ("강서구", "hechi", "낙동강 하구 습지"),
            ("연제구", "toto", "부산 시청 도심"),
            ("수영구", "luna", "광안대교 야경"),
            ("사상구", "yarn", "신발·섬유 공장"),
            ("기장군", "nyamo", "기장 멸치·대게"),
        ]),
        (.daegu, [
            ("중구", "yarn", "서문시장 원단"),
            ("동구", "huu", "팔공산"),
            ("서구", "yarn", "염색 공단"),
            ("남구", "dochi", "앞산 숲"),
            ("북구", "yarn", "섬유 공단"),
            ("수성구", "baseball", "라이온즈파크"),
            ("달서구", "kuru", "83타워 도심"),
            ("달성군", "dochi", "비슬산"),
            ("군위군", "luna", "화산마을 별"),
        ]),
        (.incheon, [
            ("중구", "nyamo", "차이나타운 짜장면"),
            ("동구", "gwiyo", "배다리 헌책방 골목"),
            ("미추홀구", "baseball", "랜더스필드"),
            ("연수구", "kuru", "송도 도심"),
            ("남동구", "hechi", "소래습지"),
            ("부평구", "yarn", "부평 지하상가 옷가게"),
            ("계양구", "mori", "계양산"),
            ("서구", "sunny", "정서진 노을"),
            ("강화군", "tori", "강화 들판"),
            ("옹진군", "otter", "섬과 바다"),
        ]),
        (.gwangju, [
            ("동구", "gwiyo", "충장로·동명동 골목"),
            ("서구", "nyamo", "양동시장"),
            ("남구", "yarn", "양림동 공예"),
            ("북구", "baseball", "챔피언스필드"),
            ("광산구", "deogi", "황룡강 산책"),
        ]),
        (.daejeon, [
            ("동구", "mori", "식장산"),
            ("중구", "nyamo", "성심당 빵"),
            ("서구", "kuru", "둔산 도심"),
            ("유성구", "toto", "대덕연구단지 과학"),
            ("대덕구", "otter", "대청호"),
        ]),
        (.ulsan, [
            ("중구", "gwiyo", "원도심 골목"),
            ("남구", "kuru", "삼산 도심"),
            ("동구", "otter", "일산해수욕장"),
            ("북구", "mupu", "무룡산"),
            ("울주군", "sunny", "간절곶 해돋이"),
        ]),
        (.sejong, [
            ("세종시", "toto", "미래 행정도시"),
        ]),
        (.gyeonggi, [
            ("수원시", "gwiyo", "행궁동 골목"),
            ("성남시", "kuru", "판교 도심"),
            ("의정부시", "nyamo", "부대찌개"),
            ("안양시", "mori", "수리산"),
            ("부천시", "toto", "만화·영화 판타지"),
            ("광명시", "sia", "광명동굴 와인"),
            ("평택시", "deogi", "평택 들판 산책"),
            ("동두천시", "mupu", "소요산"),
            ("안산시", "hechi", "시화호 갈대습지"),
            ("고양시", "kuru", "일산 도심"),
            ("과천시", "toto", "국립과천과학관"),
            ("구리시", "tori", "한강 코스모스 들판"),
            ("남양주시", "popo", "다산 정약용 차"),
            ("오산시", "chiko", "물향기수목원"),
            ("시흥시", "hechi", "갯골생태공원"),
            ("군포시", "tori", "철쭉동산"),
            ("의왕시", "otter", "왕송호수"),
            ("하남시", "kuru", "스타필드"),
            ("용인시", "toto", "놀이공원"),
            ("파주시", "gwiyo", "헤이리 예술마을"),
            ("이천시", "popo", "이천 도자기"),
            ("안성시", "gwiyo", "안성맞춤 유기 방울"),
            ("김포시", "tori", "김포 들녘"),
            ("화성시", "sia", "송산 포도"),
            ("광주시", "popo", "조선백자 가마터"),
            ("양주시", "mupu", "불곡산"),
            ("포천시", "luna", "천문과학관"),
            ("여주시", "popo", "여주 도자기"),
            ("연천군", "dochi", "DMZ 숲과 선사유적"),
            ("가평군", "mori", "잣나무 숲"),
            ("양평군", "mori", "두물머리"),
        ]),
        (.gangwon, [
            ("춘천시", "nyamo", "닭갈비·막국수"),
            ("원주시", "chiko", "치악산"),
            ("강릉시", "popo", "강릉 커피"),
            ("동해시", "sunny", "추암 해돋이"),
            ("태백시", "luna", "고원의 별"),
            ("속초시", "mupu", "설악산"),
            ("삼척시", "otter", "삼척 해변"),
            ("홍천군", "mori", "홍천 숲"),
            ("횡성군", "nyamo", "횡성 한우"),
            ("영월군", "luna", "별마로천문대"),
            ("평창군", "chiko", "오대산 다람쥐"),
            ("정선군", "huu", "정선 깊은 숲"),
            ("철원군", "hechi", "철새 두루미"),
            ("화천군", "otter", "산천어 축제"),
            ("양구군", "dochi", "DMZ 생태"),
            ("인제군", "mori", "자작나무숲"),
            ("고성군", "sunny", "통일전망대 해돋이"),
            ("양양군", "otter", "서핑 바다"),
        ]),
        (.chungbuk, [
            ("청주시", "yarn", "공예비엔날레"),
            ("충주시", "dia", "충주 사과"),
            ("제천시", "mupu", "월악산"),
            ("보은군", "dochi", "속리산"),
            ("옥천군", "sia", "옥천 포도"),
            ("영동군", "sia", "영동 포도·와인"),
            ("증평군", "tori", "증평 들판"),
            ("진천군", "gwiyo", "종박물관 종소리"),
            ("괴산군", "dochi", "산막이옛길 숲"),
            ("음성군", "suri", "음성 수박"),
            ("단양군", "huu", "소백산"),
        ]),
        (.chungnam, [
            ("천안시", "chiko", "호두과자, 다람쥐가 좋아하는 호두"),
            ("공주시", "chiko", "공주 알밤"),
            ("보령시", "otter", "머드축제"),
            ("아산시", "chiko", "곡교천 은행나무길"),
            ("서산시", "hechi", "천수만 철새"),
            ("논산시", "riru", "논산 딸기"),
            ("계룡시", "mupu", "계룡산"),
            ("당진시", "sunny", "왜목마을 해돋이"),
            ("금산군", "popo", "인삼차"),
            ("부여군", "suri", "부여 수박"),
            ("서천군", "hechi", "서천 갯벌·국립생태원"),
            ("청양군", "riru", "청양고추"),
            ("홍성군", "deogi", "홍성 시골길"),
            ("예산군", "dia", "예산 사과"),
            ("태안군", "otter", "태안 해변"),
        ]),
        (.jeonbuk, [
            ("전주시", "gwiyo", "한옥마을 골목"),
            ("군산시", "nyamo", "근대골목 빵집"),
            ("익산시", "mellu", "익산 멜론"),
            ("정읍시", "mupu", "내장산 단풍"),
            ("남원시", "luna", "광한루 달밤"),
            ("김제시", "tori", "지평선 들판"),
            ("완주군", "mori", "모악산"),
            ("진안군", "mupu", "마이산"),
            ("무주군", "huu", "반딧불이 숲"),
            ("장수군", "dia", "장수 사과"),
            ("임실군", "deogi", "오수 의견 이야기"),
            ("순창군", "riru", "순창 고추장"),
            ("고창군", "suri", "고창 수박"),
            ("부안군", "sunny", "채석강 노을"),
        ]),
        (.jeonnam, [
            ("목포시", "nyamo", "목포 낙지·민어"),
            ("여수시", "luna", "여수 밤바다"),
            ("순천시", "hechi", "순천만 습지"),
            ("나주시", "mellu", "나주 배"),
            ("광양시", "tori", "매화마을"),
            ("담양군", "mori", "대나무숲"),
            ("곡성군", "mellu", "곡성 멜론"),
            ("구례군", "otter", "섬진강 수달"),
            ("고흥군", "toto", "나로우주센터"),
            ("보성군", "popo", "보성 녹차밭"),
            ("화순군", "dochi", "화순 숲"),
            ("장흥군", "huu", "편백숲"),
            ("강진군", "popo", "강진 청자"),
            ("해남군", "sunny", "땅끝 해돋이"),
            ("영암군", "luna", "월출산, 달 뜨는 산"),
            ("무안군", "hechi", "무안 갯벌"),
            ("함평군", "tori", "나비 들판"),
            ("영광군", "nyamo", "영광 굴비"),
            ("장성군", "mupu", "축령산"),
            ("완도군", "otter", "청정 바다"),
            ("진도군", "deogi", "진돗개"),
            ("신안군", "sunny", "천일염 햇볕"),
        ]),
        (.gyeongbuk, [
            ("포항시", "sunny", "호미곶 해돋이"),
            ("경주시", "gwiyo", "황리단길·신라 금관"),
            ("김천시", "sia", "김천 자두"),
            ("안동시", "nyamo", "안동 찜닭"),
            ("구미시", "toto", "전자 산업 도시"),
            ("영주시", "dia", "영주 사과"),
            ("영천시", "luna", "보현산 천문대"),
            ("상주시", "tangerine", "상주 곶감"),
            ("문경시", "popo", "문경 찻사발"),
            ("경산시", "deogi", "경산 삽살개"),
            ("의성군", "chiko", "의성 산골"),
            ("청송군", "dia", "청송 사과"),
            ("영양군", "luna", "반딧불이 밤하늘"),
            ("영덕군", "nyamo", "영덕 대게"),
            ("청도군", "tangerine", "청도 반시"),
            ("고령군", "gwiyo", "대가야 금동관"),
            ("성주군", "mellu", "성주 참외"),
            ("칠곡군", "dochi", "가산 숲"),
            ("예천군", "huu", "회룡포 숲"),
            ("봉화군", "chiko", "백두대간수목원"),
            ("울진군", "mori", "금강소나무숲"),
            ("울릉군", "kuru", "구름 걸린 섬"),
        ]),
        (.gyeongnam, [
            ("창원시", "baseball", "NC 다이노스"),
            ("진주시", "nyamo", "진주 냉면"),
            ("통영시", "otter", "통영 바다"),
            ("사천시", "toto", "항공우주"),
            ("김해시", "gwiyo", "가야 금관"),
            ("밀양시", "dia", "얼음골 사과"),
            ("거제시", "otter", "거제 해수욕장"),
            ("양산시", "huu", "통도사 숲"),
            ("의령군", "riru", "망개 열매"),
            ("함안군", "suri", "함안 수박"),
            ("창녕군", "hechi", "우포늪"),
            ("고성군", "toto", "공룡 엑스포"),
            ("남해군", "tangerine", "남해 유자"),
            ("하동군", "popo", "하동 녹차"),
            ("산청군", "mupu", "지리산"),
            ("함양군", "mori", "상림 숲"),
            ("거창군", "dia", "거창 사과"),
            ("합천군", "huu", "가야산 해인사 숲"),
        ]),
        (.jeju, [
            ("제주시", "kuru", "한라산 구름"),
            ("서귀포시", "tangerine", "서귀포 귤"),
        ]),
    ]
}
