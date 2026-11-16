# SCOO 서버 (Supabase)

프로젝트: `ofwexbasbwumfvswkixb` (`https://ofwexbasbwumfvswkixb.supabase.co`)

## 처음 한 번

1. **Authentication → Sign In / Providers → Anonymous sign-ins**를 켜요. 앱은 로그인 화면 없이 익명 계정으로 시작해요.
2. **SQL Editor**에 `migrations/20261116000000_accounts_and_bottles.sql`을 붙여 넣고 실행해요.
3. **Project Settings → API Keys**의 **publishable(anon) 키**를 앱 설정에 넣어요(`scripts/generate_xcodeproj.py`의 `SUPABASE_ANON_KEY`). 이 키는 앱에 들어가도 되는 공개 키예요. **secret / service_role 키는 절대 앱이나 저장소에 넣지 마세요.**

## 들어 있는 것

| 이름 | 하는 일 |
| --- | --- |
| `profiles` | 계정마다 한 줄(닉네임, 시작한 구, 테스터 여부). 가입하면 자동으로 생겨요 |
| `bottles` | 유리병. 바다에 떠 있다가(`receiver` 없음) 다른 사람이 유리병을 띄우면 서로 맞바꿔요 |
| `my_bottles` (뷰) | 앱이 읽는 내 유리병 목록. 상대방이 누군지는 보여주지 않아요 |
| `send_bottle(...)` | 유리병 띄우기. 하루 1번(테스터 50번), 테스터만 1분 배송 |
| `open_bottle(id)` | 도착한 유리병 열기(한 번만) |

모든 표에 행 수준 보안(RLS)이 켜져 있고, 유리병은 함수로만 만들고 바꿀 수 있어요. 새 계정은 지금 테스트 기간이라 `is_tester = true`로 시작해요. 정식 출시 때 기본값을 `false`로 바꾸세요.

## 로컬에서 확인

`tests/`에는 Supabase의 `auth` 스키마를 흉내 낸 준비 SQL과 교환 시나리오가 있어요. PostgreSQL 16에서 `local_supabase_stubs.sql` → 마이그레이션 → `bottles_scenario.sql` 순서로 실행하면 교환, 하루 제한, 권한 거부를 확인할 수 있어요.
