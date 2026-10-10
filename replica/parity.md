## Parity: 90.4 / 100

features 90.4  (127 counted, must-haves 42 of 42 done)

## By area, weakest first
- 악보 설정                         62.5  (3 features)
- 마디                            64.3  (5 features)
- 보기                            81.2  (5 features)
- 선택                            88.1  (11 features)
- 입력                            91.5  (22 features)
- 편집                            91.7  (36 features)
- 재생                            91.7  (7 features)
- 기호                            93.2  (35 features)
- 저장                           100.0  (3 features)

## Missing, in build order
- [should] 선택: 길게 눌러 컨텍스트 메뉴 열기, partial  (꾹 눌렀다 떼면 팔레트 목록이 뜸. 선택 내용에 따라 달라지는 메뉴는 아님)
- [should] 선택: 셈여림·글자 등 음표가 아닌 기호를 직접 눌러 고르기, partial  (코드 기호·가사·빠르기표·적힌 글자는 눌러서 바로 고침. 셈여림은 붙은 음을 고른 뒤 팔레트에서)
- [could] 기호: 글자 모양 바꾸기(글꼴·크기), no
- [could] 기호: 코드 표시 방식(로마 숫자·Nashville 숫자·코드 모양), no
- [could] 마디: 마디 번호 표시·다시 매기기, no
- [could] 마디: 보표 묶음(brace·bracket·barline), no
- [could] 보기: 화면 보기·인쇄 보기·이어 보기 전환, no
- [could] 악보 설정: 악보 중간에서 악기 바꾸기, no  (파트 전체의 악기만 바꿈)
- [could] 입력: MIDI 건반으로 입력, no
- [could] 입력: 길이: 겹온음표(double whole), no
- [could] 입력: 메트로놈에 맞춰 실시간 녹음 입력, no
- [could] 입력: 음표 도구를 누른 채 밀어서 한 번에 길이 고르기, no
- [could] 재생: 믹서(악기별 음량·좌우·솔로), no
- [could] 편집: 붙여넣을 때 박 위치가 달라도 마디를 넘겨 다시 흘리기(paste reflow), no
- [could] 편집: 사분음(quarter tone) 임시표, no
- [could] 편집: 코드 기호·손가락 번호 줄 맞추기, no
- [could] 기호: 늘임표의 재생 길이 조절, partial  (늘임표 음을 두 배로 늘여 재생. 길이를 고르지는 못함)
- [could] 기호: 도돌이 횟수 지정, partial  (악보 화면의 재생 순서에서 구간 반복 횟수를 정함. 도돌이표에 숫자를 적지는 않음)
- [could] 기호: 박자표: C·컷타임 기호·빔 묶음 패턴(3+2+2), partial  (C·컷타임 기호는 됨. 빔 묶음 패턴은 없음)
- [could] 기호: 스윙, partial  (마디 기호 팔레트의 Swing·Straight. 8분음표를 셋잇단 느낌으로. 세기·16분 스윙 조절은 없음)
- [could] 기호: 재즈 fall·scoop, partial  (악보 파일에는 기록됨(Scoop·Plop·Doit·Fall). 화면에는 그려지지 않음(조판 엔진이 그리지 않음))
- [could] 기호: 조표·박자표 숨기기와 줄 끝 예고 표시 끄기, partial  (그 마디에 적힌 박자표·조표 숨기기. 줄 끝 예고 표시 끄기는 없음)
- [could] 마디: 다음 마디와 한 줄에 묶기, partial  (줄은 적힌 줄바꿈으로만 나뉘므로 다음 마디의 줄바꿈을 끄면 같은 결과)
- [could] 보기: 성부 색·음역 밖 음 빨갛게, partial  (음역 밖 음을 붉게 표시(마디 편집 메뉴). 성부 색은 없음)
- [could] 선택: 가사만·코드만 선택, partial  (고른 구간의 가사 지우기·코드 지우기로 같은 일을 함)
- [could] 악보 설정: 악기 추가·삭제·순서 바꾸기, partial  (아래 보표 추가·삭제와 악기 바꾸기만)
- [could] 편집: 다른 성부로 붙여넣기·성부로 보내기·성부 맞바꾸기, partial  (두 성부 맞바꾸기만)
- [could] 편집: 두 보표 사이로 음 옮기기(switch staff)·보표 넘는 빔(cross staff), partial  (다른 보표로 보내기(성부는 그대로). 손 바꾸기와 보표 넘는 빔을 따로 고르지는 못함)
- [could] 편집: 쉼표·기호 숨기기와 다시 보이기, partial  (음표·쉼표 숨기기(모양 팔레트). 숨긴 것은 화살표로 가서 다시 눌러 보이게 함. 숨긴 것 한꺼번에 보기는 없음)
- [could] 편집: 잇단음표 비율 직접 지정·숫자/괄호 표시 방식, partial  (3·5·6·7만. 표시 방식 선택 없음)
- [could] 편집: 큐 음표·고스트 음표, partial  (괄호 음표(ghost)만)

## Left out on purpose (not scored)
- 손글씨 인식 입력: MyScript 엔진(유료 라이선스)이 하는 일. D-222에서 범위 밖으로 결정
- 기타 지판·드럼 패드 입력: 피아노 앱 범위 밖(D-222)
- 기타 코드 다이어그램: 피아노 앱 범위 밖
- 악기별 주법(기타·하프 등): 피아노 앱 범위 밖
- TAB·드럼 보표: 피아노 앱 범위 밖
- 전용 음원 라이브러리: 원본이 소유한 녹음. 복제 대상 아님

## Yours, not in the original (not scored)
- 원본 악보 사진을 마디별로 나란히 보기
- 마디 길이 경고(박자보다 짧음·김)
