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

/// One 시군구: its own local character, and the 5 characters a newcomer here can start with
/// (the local one plus the local characters of the nearest places, so neighbours share friends).
struct Region: Hashable, Identifiable {
    let province: Province
    /// "마포구", "가평군", "수원시"
    let name: String
    /// The character that lives here.
    let friendID: String
    /// Why that character lives here.
    let note: String
    /// Roughly where the 시군구 office is, for finding neighbours.
    let latitude: Double
    let longitude: Double
    /// The 5 characters a first launch here draws from (local one first).
    let candidates: [String]

    /// Stable key, also what the app stores: "서울 마포구". 세종 is just "세종".
    var id: String { province == .sejong ? province.short : "\(province.short) \(name)" }
    var title: String { id }
    var friend: Species? { Species.find(friendID) }
    var candidateSpecies: [Species] { candidates.compactMap(Species.find) }

    /// The first friend for someone who starts here: one of the 5, at random.
    func drawStarter<G: RandomNumberGenerator>(using generator: inout G) -> Species {
        candidateSpecies.randomElement(using: &generator) ?? friend ?? Species.all[0]
    }
}

enum Regions {
    static let all: [Region] = table.flatMap { province, rows in
        rows.map { Region(province: province, name: $0.name, friendID: $0.friend, note: $0.note,
                          latitude: $0.lat, longitude: $0.lng, candidates: $0.five.split(separator: " ").map(String.init)) }
    }
    private static let byID: [String: Region] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func find(_ id: String) -> Region? { byID[id] }

    /// A stored value, including those saved before regions went nationwide (just "마포구", always Seoul).
    static func resolve(_ stored: String) -> Region? {
        if let region = byID[stored] { return region }
        return all.first { $0.province == .seoul && $0.name == stored }
    }

    static func of(_ province: Province) -> [Region] { all.filter { $0.province == province } }

    /// Where a character lives as the local one.
    static func homes(of speciesID: String) -> [Region] { all.filter { $0.friendID == speciesID } }

    /// Where a character can be a newcomer's first friend (its rarity: fewer places, rarer).
    static func startsIn(_ speciesID: String) -> [Region] { all.filter { $0.candidates.contains(speciesID) } }

    /// Someone with no usable position: a random place, then one of its 5 (common characters come up more).
    static func randomStarter<G: RandomNumberGenerator>(using generator: inout G) -> Species {
        all.randomElement(using: &generator)!.drawStarter(using: &generator)
    }

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

    // MARK: The table (시도 → 시군구, local character, why, position, the 5 starters)
    // `five` is the local character plus the local characters of the nearest places; edit freely.

    struct Row {
        let name: String, friend: String, note: String, lat: Double, lng: Double, five: String
    }
    private static func R(_ name: String, _ friend: String, _ note: String, _ lat: Double, _ lng: Double, _ five: String) -> Row {
        Row(name: name, friend: friend, note: note, lat: lat, lng: lng, five: five)
    }

    static let table: [(Province, [Row])] = [
        (.seoul, [
            R("종로구", "popo", "인사동 찻집", 37.573, 126.979, "popo riru gwiyo tori toto"),
            R("중구", "riru", "남대문·중부시장 과일", 37.564, 126.998, "riru popo tori otter toto"),
            R("용산구", "toto", "전쟁기념관·남산타워 하늘", 37.532, 126.99, "toto riru popo mori kuru"),
            R("성동구", "otter", "중랑천 수달", 37.563, 127.037, "otter yarn tori riru chiko"),
            R("광진구", "chiko", "어린이대공원", 37.538, 127.082, "chiko baseball suri kuru otter"),
            R("동대문구", "yarn", "동대문 원단시장", 37.574, 127.04, "yarn otter tori riru popo"),
            R("중랑구", "hechi", "중랑천 습지", 37.606, 127.093, "hechi tori yarn dochi otter"),
            R("성북구", "tori", "성북동 언덕", 37.589, 127.017, "tori yarn riru otter popo"),
            R("강북구", "dia", "북한산 자락 과수", 37.64, 127.026, "dia dochi huu tori hechi"),
            R("도봉구", "huu", "도봉산 부엉이", 37.669, 127.047, "huu dochi dia nyamo hechi"),
            R("노원구", "dochi", "불암산", 37.654, 127.056, "dochi huu dia hechi tori"),
            R("은평구", "mupu", "북한산 너구리", 37.603, 126.929, "mupu gwiyo deogi popo riru"),
            R("서대문구", "gwiyo", "신촌 골목", 37.579, 126.937, "gwiyo mupu deogi popo riru"),
            R("마포구", "deogi", "연남동 산책길", 37.566, 126.902, "deogi gwiyo kuru mupu sunny"),
            R("양천구", "sia", "목동 공원", 37.517, 126.866, "sia kuru baseball sunny deogi"),
            R("강서구", "sunny", "서울식물원 햇살", 37.551, 126.85, "sunny sia deogi kuru baseball"),
            R("구로구", "baseball", "고척돔", 37.495, 126.888, "baseball sia kuru tangerine mori"),
            R("금천구", "tangerine", "금천 시장", 37.457, 126.896, "tangerine sia baseball luna mori"),
            R("영등포구", "kuru", "여의도 빌딩숲", 37.526, 126.896, "kuru sia baseball mori deogi"),
            R("동작구", "mori", "현충원 숲", 37.512, 126.94, "mori luna kuru toto baseball"),
            R("관악구", "luna", "낙성대, 별이 떨어진 곳", 37.478, 126.952, "luna mori tangerine baseball toto"),
            R("서초구", "mellu", "양재 꽃·과일", 37.484, 127.033, "mellu kuru toto luna baseball"),
            R("강남구", "kuru", "멋진 도심", 37.517, 127.047, "kuru mellu chiko otter baseball"),
            R("송파구", "baseball", "잠실야구장", 37.515, 127.106, "baseball suri chiko kuru mellu"),
            R("강동구", "suri", "강동 텃밭", 37.53, 127.124, "suri baseball chiko kuru tori"),
        ]),
        (.busan, [
            R("중구", "nyamo", "자갈치·국제시장 먹거리", 35.106, 129.032, "nyamo sunny gwiyo otter hechi"),
            R("서구", "sunny", "송도 해수욕장 햇살", 35.098, 129.024, "sunny nyamo gwiyo otter hechi"),
            R("동구", "gwiyo", "초량 이바구길 골목", 35.129, 129.045, "gwiyo nyamo sunny kuru otter"),
            R("영도구", "otter", "태종대 바다", 35.091, 129.068, "otter nyamo sunny gwiyo luna"),
            R("부산진구", "kuru", "서면 도심", 35.163, 129.053, "kuru toto gwiyo sunny baseball"),
            R("동래구", "baseball", "사직야구장", 35.205, 129.084, "baseball toto huu kuru luna"),
            R("남구", "sunny", "오륙도 해돋이", 35.137, 129.084, "sunny luna gwiyo kuru toto"),
            R("북구", "deogi", "화명 강변 산책길", 35.197, 128.99, "deogi hechi yarn kuru toto"),
            R("해운대구", "otter", "해운대 해수욕장", 35.163, 129.164, "otter luna toto sunny baseball"),
            R("사하구", "hechi", "을숙도 철새", 35.104, 128.975, "hechi sunny nyamo yarn gwiyo"),
            R("금정구", "huu", "금정산 숲", 35.243, 129.092, "huu baseball toto kuru deogi"),
            R("강서구", "hechi", "낙동강 하구 습지", 35.212, 128.981, "hechi deogi yarn kuru gwiyo"),
            R("연제구", "toto", "부산 시청 도심", 35.176, 129.08, "toto kuru baseball sunny luna"),
            R("수영구", "luna", "광안대교 야경", 35.146, 129.113, "luna sunny toto otter kuru"),
            R("사상구", "yarn", "신발·섬유 공장", 35.153, 128.991, "yarn deogi gwiyo hechi kuru"),
            R("기장군", "nyamo", "기장 멸치·대게", 35.245, 129.222, "nyamo otter huu baseball luna"),
        ]),
        (.daegu, [
            R("중구", "yarn", "서문시장 원단", 35.869, 128.606, "yarn baseball dochi huu kuru"),
            R("동구", "huu", "팔공산", 35.887, 128.636, "huu baseball yarn dochi kuru"),
            R("서구", "yarn", "염색 공단", 35.872, 128.559, "yarn dochi kuru baseball huu"),
            R("남구", "dochi", "앞산 숲", 35.846, 128.598, "dochi yarn baseball huu kuru"),
            R("북구", "yarn", "섬유 공단", 35.886, 128.583, "yarn dochi huu baseball kuru"),
            R("수성구", "baseball", "라이온즈파크", 35.858, 128.631, "baseball yarn dochi huu kuru"),
            R("달서구", "kuru", "83타워 도심", 35.83, 128.533, "kuru yarn dochi baseball huu"),
            R("달성군", "dochi", "비슬산", 35.775, 128.431, "dochi kuru yarn gwiyo baseball"),
            R("군위군", "luna", "화산마을 별", 36.243, 128.573, "luna chiko toto dochi nyamo"),
        ]),
        (.incheon, [
            R("중구", "nyamo", "차이나타운 짜장면", 37.474, 126.621, "nyamo gwiyo baseball kuru sunny"),
            R("동구", "gwiyo", "배다리 헌책방 골목", 37.474, 126.643, "gwiyo baseball nyamo kuru yarn"),
            R("미추홀구", "baseball", "랜더스필드", 37.464, 126.65, "baseball gwiyo nyamo kuru hechi"),
            R("연수구", "kuru", "송도 도심", 37.41, 126.678, "kuru hechi baseball gwiyo nyamo"),
            R("남동구", "hechi", "소래습지", 37.447, 126.731, "hechi kuru yarn toto baseball"),
            R("부평구", "yarn", "부평 지하상가 옷가게", 37.507, 126.722, "yarn mori toto sunny hechi"),
            R("계양구", "mori", "계양산", 37.538, 126.738, "mori yarn toto sunny tori"),
            R("서구", "sunny", "정서진 노을", 37.546, 126.676, "sunny mori yarn tori gwiyo"),
            R("강화군", "tori", "강화 들판", 37.747, 126.488, "tori gwiyo sunny mori kuru"),
            R("옹진군", "otter", "섬과 바다", 37.45, 126.2, "otter nyamo gwiyo baseball tori"),
        ]),
        (.gwangju, [
            R("동구", "gwiyo", "충장로·동명동 골목", 35.146, 126.923, "gwiyo yarn nyamo baseball dochi"),
            R("서구", "nyamo", "양동시장", 35.152, 126.89, "nyamo yarn gwiyo baseball deogi"),
            R("남구", "yarn", "양림동 공예", 35.133, 126.902, "yarn nyamo gwiyo baseball deogi"),
            R("북구", "baseball", "챔피언스필드", 35.174, 126.912, "baseball nyamo gwiyo yarn deogi"),
            R("광산구", "deogi", "황룡강 산책", 35.14, 126.794, "deogi nyamo yarn baseball gwiyo"),
        ]),
        (.daejeon, [
            R("동구", "mori", "식장산", 36.312, 127.455, "mori nyamo otter kuru sia"),
            R("중구", "nyamo", "성심당 빵", 36.326, 127.421, "nyamo otter mori kuru toto"),
            R("서구", "kuru", "둔산 도심", 36.355, 127.384, "kuru toto otter nyamo mori"),
            R("유성구", "toto", "대덕연구단지 과학", 36.362, 127.356, "toto kuru otter nyamo mori"),
            R("대덕구", "otter", "대청호", 36.347, 127.416, "otter nyamo kuru mori toto"),
        ]),
        (.ulsan, [
            R("중구", "gwiyo", "원도심 골목", 35.569, 129.333, "gwiyo kuru mupu sunny otter"),
            R("남구", "kuru", "삼산 도심", 35.544, 129.33, "kuru gwiyo mupu sunny otter"),
            R("동구", "otter", "일산해수욕장", 35.505, 129.417, "otter kuru mupu gwiyo sunny"),
            R("북구", "mupu", "무룡산", 35.583, 129.361, "mupu gwiyo kuru otter sunny"),
            R("울주군", "sunny", "간절곶 해돋이", 35.522, 129.243, "sunny kuru gwiyo mupu otter"),
        ]),
        (.sejong, [
            R("세종시", "toto", "미래 행정도시", 36.48, 127.289, "toto chiko kuru otter nyamo"),
        ]),
        (.gyeonggi, [
            R("수원시", "gwiyo", "행궁동 골목", 37.263, 127.029, "gwiyo otter chiko toto tori"),
            R("성남시", "kuru", "판교 도심", 37.42, 127.127, "kuru baseball mellu popo suri"),
            R("의정부시", "nyamo", "부대찌개", 37.738, 127.034, "nyamo mupu huu dochi dia"),
            R("안양시", "mori", "수리산", 37.394, 126.957, "mori tori toto otter tangerine"),
            R("부천시", "toto", "만화·영화 판타지", 37.504, 126.766, "toto yarn mori hechi sia"),
            R("광명시", "sia", "광명동굴 와인", 37.479, 126.865, "sia baseball tangerine kuru mori"),
            R("평택시", "deogi", "평택 들판 산책", 36.992, 127.113, "deogi gwiyo chiko toto sia"),
            R("동두천시", "mupu", "소요산", 37.904, 127.061, "mupu luna nyamo dochi huu"),
            R("안산시", "hechi", "시화호 갈대습지", 37.322, 126.831, "hechi tori otter sia mori"),
            R("고양시", "kuru", "일산 도심", 37.658, 126.832, "kuru mupu tori sunny deogi"),
            R("과천시", "toto", "국립과천과학관", 37.429, 126.988, "toto mori luna mellu tangerine"),
            R("구리시", "tori", "한강 코스모스 들판", 37.594, 127.13, "tori hechi suri chiko yarn"),
            R("남양주시", "popo", "다산 정약용 차", 37.636, 127.216, "popo tori kuru hechi suri"),
            R("오산시", "chiko", "물향기수목원", 37.15, 127.077, "chiko gwiyo toto deogi sia"),
            R("시흥시", "hechi", "갯골생태공원", 37.38, 126.803, "hechi kuru tangerine tori sia"),
            R("군포시", "tori", "철쭉동산", 37.362, 126.935, "tori otter mori toto hechi"),
            R("의왕시", "otter", "왕송호수", 37.345, 126.968, "otter tori mori toto gwiyo"),
            R("하남시", "kuru", "스타필드", 37.539, 127.215, "kuru suri tori baseball popo"),
            R("용인시", "toto", "놀이공원", 37.241, 127.178, "toto chiko gwiyo kuru popo"),
            R("파주시", "gwiyo", "헤이리 예술마을", 37.76, 126.78, "gwiyo kuru tori mupu nyamo"),
            R("이천시", "popo", "이천 도자기", 37.272, 127.435, "popo toto mori kuru gwiyo"),
            R("안성시", "gwiyo", "안성맞춤 유기 방울", 37.008, 127.28, "gwiyo deogi chiko toto popo"),
            R("김포시", "tori", "김포 들녘", 37.615, 126.716, "tori sunny mori kuru yarn"),
            R("화성시", "sia", "송산 포도", 37.2, 126.831, "sia hechi gwiyo otter tori"),
            R("광주시", "popo", "조선백자 가마터", 37.429, 127.255, "popo kuru suri baseball chiko"),
            R("양주시", "mupu", "불곡산", 37.785, 127.046, "mupu nyamo huu dochi dia"),
            R("포천시", "luna", "천문과학관", 37.895, 127.2, "luna mupu nyamo dochi huu"),
            R("여주시", "popo", "여주 도자기", 37.298, 127.637, "popo mori chiko nyamo suri"),
            R("연천군", "dochi", "DMZ 숲과 선사유적", 38.096, 127.075, "dochi mupu hechi luna nyamo"),
            R("가평군", "mori", "잣나무 숲", 37.831, 127.51, "mori nyamo luna popo otter"),
            R("양평군", "mori", "두물머리", 37.492, 127.488, "mori popo kuru suri tori"),
        ]),
        (.gangwon, [
            R("춘천시", "nyamo", "닭갈비·막국수", 37.881, 127.73, "nyamo mori otter dochi luna"),
            R("원주시", "chiko", "치악산", 37.342, 127.92, "chiko nyamo popo mupu dia"),
            R("강릉시", "popo", "강릉 커피", 37.752, 128.876, "popo sunny otter huu mupu"),
            R("동해시", "sunny", "추암 해돋이", 37.525, 129.114, "sunny otter popo luna huu"),
            R("태백시", "luna", "고원의 별", 37.164, 128.986, "luna otter chiko huu sunny"),
            R("속초시", "mupu", "설악산", 38.207, 128.592, "mupu otter sunny mori dochi"),
            R("삼척시", "otter", "삼척 해변", 37.45, 129.165, "otter sunny luna popo huu"),
            R("홍천군", "mori", "홍천 숲", 37.697, 127.889, "mori nyamo chiko dochi otter"),
            R("횡성군", "nyamo", "횡성 한우", 37.492, 127.985, "nyamo chiko mori popo mupu"),
            R("영월군", "luna", "별마로천문대", 37.184, 128.462, "luna chiko huu mupu dia"),
            R("평창군", "chiko", "오대산 다람쥐", 37.371, 128.39, "chiko luna huu mupu nyamo"),
            R("정선군", "huu", "정선 깊은 숲", 37.381, 128.661, "huu chiko luna sunny popo"),
            R("철원군", "hechi", "철새 두루미", 38.147, 127.313, "hechi dochi luna mupu otter"),
            R("화천군", "otter", "산천어 축제", 38.106, 127.708, "otter nyamo dochi mori hechi"),
            R("양구군", "dochi", "DMZ 생태", 38.11, 127.99, "dochi mori otter nyamo sunny"),
            R("인제군", "mori", "자작나무숲", 38.07, 128.17, "mori dochi otter mupu sunny"),
            R("고성군", "sunny", "통일전망대 해돋이", 38.381, 128.468, "sunny mupu otter mori dochi"),
            R("양양군", "otter", "서핑 바다", 38.075, 128.619, "otter mupu sunny mori popo"),
        ]),
        (.chungbuk, [
            R("청주시", "yarn", "공예비엔날레", 36.642, 127.489, "yarn tori gwiyo toto dochi"),
            R("충주시", "dia", "충주 사과", 36.991, 127.926, "dia suri dochi mupu tori"),
            R("제천시", "mupu", "월악산", 37.133, 128.191, "mupu huu luna dia chiko"),
            R("보은군", "dochi", "속리산", 36.489, 127.729, "dochi sia yarn mori otter"),
            R("옥천군", "sia", "옥천 포도", 36.306, 127.571, "sia mori nyamo otter kuru"),
            R("영동군", "sia", "영동 포도·와인", 36.175, 127.783, "sia huu popo mori dochi"),
            R("증평군", "tori", "증평 들판", 36.785, 127.581, "tori gwiyo yarn dochi suri"),
            R("진천군", "gwiyo", "종박물관 종소리", 36.855, 127.436, "gwiyo tori yarn suri chiko"),
            R("괴산군", "dochi", "산막이옛길 숲", 36.815, 127.787, "dochi suri tori dia gwiyo"),
            R("음성군", "suri", "음성 수박", 36.94, 127.69, "suri dochi tori dia gwiyo"),
            R("단양군", "huu", "소백산", 36.985, 128.366, "huu mupu luna dia chiko"),
        ]),
        (.chungnam, [
            R("천안시", "chiko", "호두과자, 다람쥐가 좋아하는 호두", 36.815, 127.114, "chiko deogi gwiyo dia yarn"),
            R("공주시", "chiko", "공주 알밤", 36.447, 127.119, "chiko toto mupu kuru suri"),
            R("보령시", "otter", "머드축제", 36.333, 126.613, "otter riru suri hechi deogi"),
            R("아산시", "chiko", "곡교천 은행나무길", 36.79, 127.002, "chiko dia deogi sunny gwiyo"),
            R("서산시", "hechi", "천수만 철새", 36.785, 126.45, "hechi otter sunny deogi dia"),
            R("논산시", "riru", "논산 딸기", 36.187, 127.099, "riru mupu suri chiko mellu"),
            R("계룡시", "mupu", "계룡산", 36.274, 127.249, "mupu toto kuru nyamo riru"),
            R("당진시", "sunny", "왜목마을 해돋이", 36.89, 126.646, "sunny hechi dia deogi chiko"),
            R("금산군", "popo", "인삼차", 36.109, 127.488, "popo huu mori sia nyamo"),
            R("부여군", "suri", "부여 수박", 36.276, 126.91, "suri riru chiko otter hechi"),
            R("서천군", "hechi", "서천 갯벌·국립생태원", 36.08, 126.692, "hechi nyamo mellu otter suri"),
            R("청양군", "riru", "청양고추", 36.459, 126.802, "riru deogi otter suri dia"),
            R("홍성군", "deogi", "홍성 시골길", 36.601, 126.661, "deogi dia riru hechi otter"),
            R("예산군", "dia", "예산 사과", 36.683, 126.845, "dia chiko deogi riru sunny"),
            R("태안군", "otter", "태안 해변", 36.746, 126.298, "otter hechi sunny deogi dia"),
        ]),
        (.jeonbuk, [
            R("전주시", "gwiyo", "한옥마을 골목", 35.824, 127.148, "gwiyo mori mellu tori mupu"),
            R("군산시", "nyamo", "근대골목 빵집", 35.968, 126.737, "nyamo hechi mellu tori sunny"),
            R("익산시", "mellu", "익산 멜론", 35.948, 126.958, "mellu tori mori nyamo gwiyo"),
            R("정읍시", "mupu", "내장산 단풍", 35.57, 126.856, "mupu suri sunny tori mori"),
            R("남원시", "luna", "광한루 달밤", 35.416, 127.39, "luna mellu riru deogi otter"),
            R("김제시", "tori", "지평선 들판", 35.804, 126.881, "tori sunny mellu nyamo gwiyo"),
            R("완주군", "mori", "모악산", 35.905, 127.162, "mori gwiyo mellu mupu tori"),
            R("진안군", "mupu", "마이산", 35.792, 127.425, "mupu dia deogi gwiyo mori"),
            R("무주군", "huu", "반딧불이 숲", 36.007, 127.661, "huu popo sia mupu mori"),
            R("장수군", "dia", "장수 사과", 35.647, 127.521, "dia mupu deogi mori luna"),
            R("임실군", "deogi", "오수 의견 이야기", 35.618, 127.289, "deogi dia mupu luna gwiyo"),
            R("순창군", "riru", "순창 고추장", 35.374, 127.137, "riru mori mellu luna baseball"),
            R("고창군", "suri", "고창 수박", 35.436, 126.702, "suri mupu nyamo mori sunny"),
            R("부안군", "sunny", "채석강 노을", 35.732, 126.733, "sunny tori mupu nyamo mellu"),
        ]),
        (.jeonnam, [
            R("목포시", "nyamo", "목포 낙지·민어", 34.812, 126.392, "nyamo sunny hechi luna tori"),
            R("여수시", "luna", "여수 밤바다", 34.76, 127.662, "luna tori tangerine hechi popo"),
            R("순천시", "hechi", "순천만 습지", 34.951, 127.487, "hechi tori luna popo otter"),
            R("나주시", "mellu", "나주 배", 35.016, 126.711, "mellu deogi tori hechi yarn"),
            R("광양시", "tori", "매화마을", 34.941, 127.696, "tori popo hechi luna tangerine"),
            R("담양군", "mori", "대나무숲", 35.321, 126.988, "mori riru baseball mupu gwiyo"),
            R("곡성군", "mellu", "곡성 멜론", 35.282, 127.292, "mellu riru luna otter mori"),
            R("구례군", "otter", "섬진강 수달", 35.202, 127.463, "otter mellu luna hechi popo"),
            R("고흥군", "toto", "나로우주센터", 34.611, 127.285, "toto popo huu luna hechi"),
            R("보성군", "popo", "보성 녹차밭", 34.771, 127.08, "popo huu toto dochi luna"),
            R("화순군", "dochi", "화순 숲", 35.064, 126.987, "dochi gwiyo yarn nyamo baseball"),
            R("장흥군", "huu", "편백숲", 34.682, 126.907, "huu popo luna sunny toto"),
            R("강진군", "popo", "강진 청자", 34.642, 126.767, "popo huu sunny luna otter"),
            R("해남군", "sunny", "땅끝 해돋이", 34.573, 126.599, "sunny popo luna huu deogi"),
            R("영암군", "luna", "월출산, 달 뜨는 산", 34.8, 126.697, "luna popo huu mellu sunny"),
            R("무안군", "hechi", "무안 갯벌", 34.99, 126.482, "hechi tori mellu sunny nyamo"),
            R("함평군", "tori", "나비 들판", 35.066, 126.517, "tori hechi mellu nyamo deogi"),
            R("영광군", "nyamo", "영광 굴비", 35.277, 126.512, "nyamo tori suri mupu deogi"),
            R("장성군", "mupu", "축령산", 35.302, 126.785, "mupu suri deogi baseball mori"),
            R("완도군", "otter", "청정 바다", 34.311, 126.755, "otter sunny popo huu deogi"),
            R("진도군", "deogi", "진돗개", 34.487, 126.263, "deogi sunny nyamo otter popo"),
            R("신안군", "sunny", "천일염 햇볕", 34.833, 126.351, "sunny nyamo hechi tori luna"),
        ]),
        (.gyeongbuk, [
            R("포항시", "sunny", "호미곶 해돋이", 36.019, 129.343, "sunny gwiyo luna nyamo mupu"),
            R("경주시", "gwiyo", "황리단길·신라 금관", 35.856, 129.225, "gwiyo sunny luna mupu kuru"),
            R("김천시", "sia", "김천 자두", 36.14, 128.114, "sia toto mellu tangerine dochi"),
            R("안동시", "nyamo", "안동 찜닭", 36.568, 128.73, "nyamo chiko huu dia luna"),
            R("구미시", "toto", "전자 산업 도시", 36.12, 128.344, "toto dochi sia mellu luna"),
            R("영주시", "dia", "영주 사과", 36.806, 128.624, "dia chiko huu nyamo luna"),
            R("영천시", "luna", "보현산 천문대", 35.973, 128.939, "luna deogi gwiyo huu baseball"),
            R("상주시", "tangerine", "상주 곶감", 36.411, 128.159, "tangerine popo sia toto huu"),
            R("문경시", "popo", "문경 찻사발", 36.587, 128.187, "popo tangerine huu dochi dia"),
            R("경산시", "deogi", "경산 삽살개", 35.825, 128.741, "deogi baseball huu dochi yarn"),
            R("의성군", "chiko", "의성 산골", 36.353, 128.697, "chiko luna nyamo dia huu"),
            R("청송군", "dia", "청송 사과", 36.436, 129.057, "dia luna nyamo chiko sunny"),
            R("영양군", "luna", "반딧불이 밤하늘", 36.667, 129.112, "luna dia nyamo chiko mori"),
            R("영덕군", "nyamo", "영덕 대게", 36.415, 129.366, "nyamo dia luna sunny chiko"),
            R("청도군", "tangerine", "청도 반시", 35.647, 128.734, "tangerine dia deogi hechi baseball"),
            R("고령군", "gwiyo", "대가야 금동관", 35.726, 128.263, "gwiyo dochi huu mellu kuru"),
            R("성주군", "mellu", "성주 참외", 35.919, 128.283, "mellu dochi gwiyo toto kuru"),
            R("칠곡군", "dochi", "가산 숲", 35.996, 128.402, "dochi mellu toto yarn kuru"),
            R("예천군", "huu", "회룡포 숲", 36.658, 128.453, "huu dia popo nyamo chiko"),
            R("봉화군", "chiko", "백두대간수목원", 36.893, 128.733, "chiko dia huu nyamo luna"),
            R("울진군", "mori", "금강소나무숲", 36.993, 129.4, "mori luna otter chiko nyamo"),
            R("울릉군", "kuru", "구름 걸린 섬", 37.484, 130.906, "kuru mori otter sunny luna"),
        ]),
        (.gyeongnam, [
            R("창원시", "baseball", "NC 다이노스", 35.228, 128.682, "baseball gwiyo suri hechi deogi"),
            R("진주시", "nyamo", "진주 냉면", 35.18, 128.108, "nyamo toto riru suri mupu"),
            R("통영시", "otter", "통영 바다", 34.854, 128.433, "otter toto suri nyamo baseball"),
            R("사천시", "toto", "항공우주", 35.004, 128.065, "toto nyamo tangerine popo tori"),
            R("김해시", "gwiyo", "가야 금관", 35.229, 128.889, "gwiyo hechi deogi yarn kuru"),
            R("밀양시", "dia", "얼음골 사과", 35.504, 128.747, "dia tangerine hechi baseball huu"),
            R("거제시", "otter", "거제 해수욕장", 34.881, 128.621, "otter toto baseball hechi sunny"),
            R("양산시", "huu", "통도사 숲", 35.335, 129.037, "huu hechi baseball deogi gwiyo"),
            R("의령군", "riru", "망개 열매", 35.322, 128.262, "riru suri nyamo huu hechi"),
            R("함안군", "suri", "함안 수박", 35.272, 128.406, "suri riru baseball nyamo hechi"),
            R("창녕군", "hechi", "우포늪", 35.545, 128.492, "hechi dia tangerine dochi gwiyo"),
            R("고성군", "toto", "공룡 엑스포", 34.973, 128.322, "toto otter nyamo suri riru"),
            R("남해군", "tangerine", "남해 유자", 34.838, 127.893, "tangerine tori luna toto popo"),
            R("하동군", "popo", "하동 녹차", 35.067, 127.751, "popo tori hechi tangerine toto"),
            R("산청군", "mupu", "지리산", 35.416, 127.873, "mupu mori dia huu nyamo"),
            R("함양군", "mori", "상림 숲", 35.52, 127.725, "mori mupu dia luna huu"),
            R("거창군", "dia", "거창 사과", 35.687, 127.91, "dia mori huu mupu gwiyo"),
            R("합천군", "huu", "가야산 해인사 숲", 35.567, 128.166, "huu gwiyo dia riru hechi"),
        ]),
        (.jeju, [
            R("제주시", "kuru", "한라산 구름", 33.5, 126.531, "kuru tangerine otter deogi sunny"),
            R("서귀포시", "tangerine", "서귀포 귤", 33.254, 126.56, "tangerine kuru otter deogi sunny"),
        ]),
    ]
}
