# SCOO 서버 (Supabase)

프로젝트: `ofwexbasbwumfvswkixb` (`https://ofwexbasbwumfvswkixb.supabase.co`)

## 처음 한 번

1. **Authentication → Sign In / Providers → Anonymous sign-ins**를 켜요. 앱은 로그인 화면 없이 익명 계정으로 시작해요.
2. **SQL Editor**에 `migrations/20261116000000_accounts_and_bottles.sql`을 붙여 넣고 실행해요.
3. **publishable 키**(`sb_publishable_…`)는 이미 `scripts/generate_xcodeproj.py`의 `SUPABASE_ANON_KEY`에 들어 있어요. 앱에 들어가도 되는 공개 키예요. **secret / service_role 키는 절대 앱이나 저장소에 넣지 마세요.**

마이그레이션 두 개(`accounts_and_bottles`, `lock_handle_new_user`)는 2026-11-16에 프로젝트에 적용했고, 익명 로그인도 켜져 있어요. 1번은 대시보드에서만 바꿀 수 있어요.

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

## 실제 서버 확인

`tests/live_bottle_check.py`는 실제 프로젝트에 익명 계정 두 개를 만들어 유리병 보내기 → 교환 → 직접 쓰기·비로그인 거부 → 1분 뒤 열기 → 두 번 열기 거부를 확인해요(테스터 1분 배송이라 1분쯤 걸려요). 끝나면 출력된 두 계정 id를 SQL Editor에서 `delete from auth.users where id in (...)`로 지우세요. 2026-11-16 실행 결과 모두 통과했고 시험 계정은 지웠어요.

## 교배 그림 (`functions/breed-image`)

- 앱이 부모 A·B 그림(512px PNG)을 보내면 OpenAI 이미지 편집 API(`gpt-image-2.6-flare`, `low`, 투명 배경)로 아기를 그려 공개 버킷 `breeds/<A>-<B>.png`에 저장하고 주소를 돌려줘요. 이미 그린 조합은 바로 돌려줘요(비용 없음).
- 로그인한 계정만 부를 수 있고, 계정마다 하루 새 그림 20장까지예요(`BREED_DAILY_LIMIT`로 조절).
- **OpenAI 키는 대시보드 → Edge Functions → Secrets에 `OPENAI_API_KEY`로 넣어요.** 앱이나 저장소에는 넣지 않아요.
- 모델·품질은 `BREED_IMAGE_MODEL`, `BREED_IMAGE_QUALITY` 비밀값으로 바꿀 수 있어요.

## 친구와 편지 (`20261116000300_friends_and_messages`)

| 이름 | 하는 일 |
| --- | --- |
| `profiles.friend_code`, `profiles.hero` | 6자리 친구 코드(헷갈리는 0/O/1/I/L 제외), 친구에게 보일 캐릭터 |
| `friendships` | 요청한 쪽·받은 쪽·수락 여부. 서로 요청하면 바로 친구 |
| `messages` | 친구끼리만, 글(500자)이나 캐릭터 스티커. 분당 30통 제한 |
| `my_profile()`, `request_friend(code)`, `respond_friend(id, accept)` | 내 코드, 친구 요청, 수락·거절 |
| `send_message(to, body, sticker)`, `mark_read(friend)`, `list_friends()`, `my_messages` | 편지 보내기, 읽음, 친구 목록(마지막 편지·안 읽은 수), 대화 |

`tests/friends_scenario.sql`로 로컬에서 요청·수락·편지·읽음·다른 사람 차단을 확인했어요.
