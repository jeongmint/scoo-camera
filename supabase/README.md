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

## 로그인 (Apple · Google · 카카오)

앱은 익명 계정으로 시작하고, 설정의 **계정 · 서버**에서 Apple·Google·카카오 중 하나를 **지금 계정에 이어 붙여요**(친구·유리병·편지 그대로). 그 로그인에 이미 계정이 있으면(앱을 지웠다 다시 깐 경우 등) 그 계정으로 돌아가요.

공통 (대시보드에서 한 번):

1. **Authentication → Sign In / Providers → Allow manual linking**을 켜요. 꺼져 있으면 이어 붙이기가 `manual_linking_disabled`로 거절돼요(2026-11-17 확인 시 꺼져 있었어요).
2. **Authentication → URL Configuration → Redirect URLs**에 `scoo://auth-callback`을 추가해요. 없으면 로그인 뒤 앱으로 돌아오지 못해요.

모든 제공자의 콜백 주소는 `https://ofwexbasbwumfvswkixb.supabase.co/auth/v1/callback`이에요.

**Apple** — Providers → Apple을 켜고 Client IDs에 번들 ID `com.jeongmint.scoo`를 넣어요. 앱은 iPhone의 기본 Apple 로그인 창을 써요(엔타이틀먼트 `com.apple.developer.applesignin`, 개발자 사이트의 App ID에서도 Sign in with Apple 체크).

**Google**

1. Google Cloud Console → APIs & Services → OAuth consent screen(앱 이름, 지원 이메일)을 만들어요.
2. Credentials → Create credentials → OAuth client ID → **Web application**. Authorized redirect URIs에 위 콜백 주소를 넣어요.
3. 나온 Client ID / Client Secret을 Supabase Providers → Google에 넣고 켜요.

**카카오** — 지금 앱은 Supabase 기본 카카오 로그인을 써요(PKCE, Google과 같은 흐름). 그래서 카카오 앱에 동의항목 **이메일·닉네임·프로필 사진**이 모두 있어야 해요(없으면 `KOE205`). 카카오 로그인 리다이렉트 URI는 `https://ofwexbasbwumfvswkixb.supabase.co/auth/v1/callback`, Supabase Providers → Kakao에 REST API 키와 Client Secret.

닉네임·사진 없이 이메일만 받고 싶으면 `SupabaseConfig.kakaoEmailOnly = true`로 바꾸면 `functions/kakao-login`(배포돼 있음)을 거쳐요. 이때 필요한 설정:

1. [Kakao Developers](https://developers.kakao.com) → 앱 만들기. **REST API 키**가 Client ID예요.
2. 카카오 로그인 **사용 설정 ON**, **OpenID Connect ON**(카카오 로그인 → 고급 또는 일반).
3. 카카오 로그인 **리다이렉트 URI**에 `https://ofwexbasbwumfvswkixb.supabase.co/functions/v1/kakao-login`을 추가해요.
4. 동의항목은 **카카오계정(이메일)** 만 있으면 돼요(비즈 앱에서 열림). 닉네임·사진은 꺼 둬도 돼요.
5. **카카오 로그인 Client Secret**을 켰다면 같은 값을 Edge Functions → Secrets에 `KAKAO_CLIENT_SECRET`으로 넣어요. 꺼 두었다면 넣지 않아도 돼요.
6. Supabase Providers → Kakao는 **켜 둔 채로** Client ID에 REST API 키를 둬요. 서버가 카카오 토큰을 이 키로 확인해요.

흐름: 앱 → `kakao-login?nonce=<SHA-256>&state=…` → 카카오 로그인 → 함수가 코드를 OpenID 토큰으로 바꿔 `scoo://auth-callback?id_token=…`로 돌려줌 → 앱이 원래 nonce와 함께 `token?grant_type=id_token`(provider `kakao`)으로 계정에 이어 붙여요. 원래 nonce는 폰 밖으로 나가지 않아서, 토큰을 가로채도 쓸 수 없어요.

Google은 PKCE 흐름이에요: `auth/v1/user/identities/authorize`(이어 붙이기, 로그인한 토큰 필요) 또는 `auth/v1/authorize`(로그인)에 `skip_http_redirect=true`로 로그인 주소를 받아 앱 안 Safari 창(`ASWebAuthenticationSession`)으로 열고, `scoo://auth-callback?code=…`를 `token?grant_type=pkce`로 세션과 바꿔요. 서버 키는 쓰지 않아요.

## 알림 (`20261117000000_push`, `functions/push`)

- 새 편지, 친구 요청·수락, 유리병 짝 찾기 때 트리거가 `pg_net`으로 `push` 함수를 불러 APNs로 보내요. 함수와 트리거는 Vault의 `push_hook_secret`을 공유해서 다른 사람은 부를 수 없어요.
- 기기는 `register_push_token(token, environment)`로 토큰을 등록해요(`sandbox` = Xcode 개발 빌드, `production` = TestFlight·App Store).
- **APNs 키**: Apple Developer → Keys → 새 키(Apple Push Notifications service) → `.p8` 다운로드. Edge Functions → Secrets에 `APNS_KEY`(.p8 파일 내용 전체), `APNS_KEY_ID`, `APNS_TEAM_ID`를 넣어요. 번들이 다르면 `APNS_TOPIC`. 키가 없으면 함수는 보내지 않고 `skipped`만 돌려줘요.

## 랜덤 이름 (`20261117000100_random_nicknames`)

새 계정은 `new_nickname()`이 지은 이름("졸린 모리", "반짝이는 실타래"처럼 형용사 18개 × 캐릭터 24개)으로 시작해요. 로그인 제공자에게서 이름을 받아오지 않아요. 설정에서 언제든 바꿀 수 있어요. 2026-11-17에 적용했고 이름이 없던 계정도 채웠어요.

## 무료 Apple 개발자 계정(Personal Team)일 때

무료 팀은 **Sign in with Apple**과 **원격 푸시 알림**을 서명할 수 없어요("Personal development teams … do not support the Sign In with Apple capability"). 그래서 저장소의 기본 프로젝트는 이 둘을 빼고 빌드하고, 설정 화면에서도 Apple 버튼을 숨겨요. Google·카카오 로그인은 무료 팀에서도 돼요.

Apple Developer Program(유료)에 가입한 뒤에는 아래처럼 프로젝트를 다시 만들면 Apple 로그인이 켜져요(`SCOO-Paid.entitlements` 사용).

```bash
python3 scripts/generate_xcodeproj.py --paid-team
```

## 대화 모드 (`functions/pet-chat`, `20261117000200_pet_talk`)

- 카메라의 말풍선 버튼 → 떠 있는 친구와 음성으로 티키타카. 목소리는 iPhone에서 글자로 바뀌고(가능하면 기기 안 인식), 그 글자만 `pet-chat`으로 가요.
- `pet-chat`은 OpenAI(`gpt-5.4-mini`, 추론 없음, 2026-11-17 기준 약 1초)로 한두 문장 반말 대답과 표정(`smile|surprised|awe|yum|normal`)을 JSON으로 돌려줘요. 위험한 말에는 109·112·119 안내를 하도록 프롬프트에 넣었어요.
- 로그인한 계정만, 하루 300번(`PET_CHAT_DAILY_LIMIT`). 대화 내용은 저장하지 않고 `pet_talk_usage`에 하루 횟수만 세요. 모델은 `PET_CHAT_MODEL`, 추론 정도는 `PET_CHAT_REASONING` 비밀값으로 바꿀 수 있어요.
- 서버가 6초 안에 답하지 않거나 설정에서 'AI로 대답하기'를 끄면 앱 안의 간단한 대답(`LocalReplies`)으로 받아쳐요.

## 입양 편지 단어 (`20261118000000_bottle_moments`)

- 모르는 사람끼리 사진이 오가지 않도록, 입양한 쪽 폰은 사진을 **정해진 주제 단어**(sky·cat·flower·dog·green·sweet·sign·water·coffee·book·food)로만 바꿔 `share_moment(p_subjects)`로 보내요. 오늘의 미션과 같은 Vision 라벨을 써요.
- 서버는 그 계정이 **열어 본** 유리병 중 처음 가족이 '가끔 소식 전해줘'를 켠 것에만, 주제마다 하루 한 번 `bottle_moments`에 남겨요. 목록 밖 단어나 직접 쓰기는 거절해요.
- 읽기는 처음 가족(보낸 사람)만 돼요(RLS). 앱은 편지 사이 기간에 들어온 단어로 "오늘 새 가족이랑 고양이를 봤어!" 같은 편지를 만들어요.
- `tests/moments_scenario.sql`로 로컬에서 확인했어요(열기 전 0개, 하루 한 번, 목록 밖 거절, 직접 쓰기 거절, 남은 못 읽음). 2026-11-18 적용.

### 대화 모드 대답 순서와 무료 전환

1. **기기 안 AI**: iOS 26 + Apple Intelligence가 되는 iPhone은 Apple의 기기 안 모델이 대답해요. 무료이고 아무것도 밖으로 나가지 않아요(Xcode 26 이상으로 빌드해야 들어가요).
2. **서버 `pet-chat`**: 그 밖의 iPhone. 기본은 OpenAI. Edge Functions → Secrets에 `PET_CHAT_PROVIDER=gemini`와 `GEMINI_API_KEY`(Google AI Studio에서 발급)를 넣으면 Gemini로 바뀌어요(모델 기본값 `gemini-flash-lite-latest`, `PET_CHAT_MODEL`로 변경). Gemini 무료 등급은 테스트용이에요: 한도가 프로젝트 전체 기준이고, 보낸 내용이 Google 서비스 개선에 쓰일 수 있어요.
3. **앱 안 대답**: 서버가 6초 안에 답하지 않거나 'AI로 대답하기'를 끈 경우.

## 2026-11-18 추가 (서버 적용 대기)

아래 세 마이그레이션과 함수 하나는 저장소에 있고, 로컬 PostgreSQL에서 시나리오로 확인했어요. 실제 프로젝트에 적용할 때 Supabase가 확인을 물어요(제약 조건 바꾸기가 들어 있어서).

| 파일 | 하는 일 | 로컬 확인 |
| --- | --- | --- |
| `20261118000100_delete_account` | 설정의 계정 삭제(`delete_my_account`). 이미 도착한 유리병의 아기는 받은 사람에게 남김 | `tests/delete_account_scenario.sql` |
| `20261118000200_friend_photos_and_blocks` | 친구 편지 사진(비공개 `letters` 버킷, 친구끼리만), 신고·차단, 차단하면 편지·요청 막힘 | `tests/friend_photos_scenario.sql` |
| `20261118000300_friend_presence` | 주변 친구 보기: 100m 단위 위치를 친구에게만, 30분 뒤 사라짐 | `tests/presence_scenario.sql` |
| `functions/breed-image` | 만개한 교배종(`b_` + 12자리) 부모 허용(재교배) | — |

로컬에서는 `tests/local_storage_stubs.sql`(Storage 흉내)을 스텁 다음에 실행해요.
