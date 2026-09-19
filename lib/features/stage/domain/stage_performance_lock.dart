/// Stage Mode Performance Lock.
///
/// 뷰어 UI(크롬·메뉴·페이지 넘김)는 일반 악보 뷰어와 동일하다.
/// 공연 중 실수 방지를 위해 악보/주석 편집만 잠근다.
bool stageAllowsMenu(bool stageMode) => true;

bool stageAllowsEditing(bool stageMode) => !stageMode;

bool stageAllowsTwoFingerZoom(bool stageMode) => true;

/// 좌측 25%는 이전, 우측 25%는 다음. 가운데는 무시해 실수 터치를 막는다.
/// (레거시 스테이지 탭 존 — 뷰어는 일반 탭 동작을 쓴다.)
int? stagePageDeltaForTap({required double x, required double width}) {
  if (width <= 0) return null;
  if (x <= width * 0.25) return -1;
  if (x >= width * 0.75) return 1;
  return null;
}
