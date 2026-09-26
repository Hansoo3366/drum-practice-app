# OMR convert API

VM에서 PDF/JPG를 MusicXML로 바꿉니다. `/opt/audiveris/bin/Audiveris`, `xvfb-run`, Python Flask가 필요합니다. `/usr/local/bin/pdf-to-mxl`은 사용하지 않습니다.

1. GCP 방화벽에서 **tcp:8080** 을 엽니다.
2. VM SSH에서 이 폴더를 `/opt/omr-src`에 복사한 뒤 `sudo bash /opt/omr-src/install.sh` 를 실행합니다.
3. `curl http://127.0.0.1:8080/health`에 `"ok":true`와 `"pipeline":"pdf-multipass-v1"`이 있으면 새 서버입니다.

`POST /convert` 는 바로 `{id, status, progress}` 를 주고, Audiveris는 서버에서 계속 돕니다. 앱은 `GET /jobs/<id>` 로 진행률을 읽고 `GET /jobs/<id>/result` 로 MXL을 받습니다.

PDF는 기본적으로 **300 DPI와 400 DPI**로 각각 Audiveris를 실행합니다. 작은 기호에 400 DPI를 권장하는 [공식 입력 지침](https://audiveris.github.io/audiveris/_pages/guides/advanced/scanning/)과 [PDF 해상도 상수](https://github.com/Audiveris/audiveris/blob/master/app/src/main/java/org/audiveris/omr/image/ImageLoading.java)를 따른 후보 생성입니다. 이미지 파일은 원래 해상도로 한 번 실행합니다. 저해상도 스캔에 없는 정보를 복원하거나 잘못된 음높이를 자동 교정하는 기능은 아닙니다.

400 DPI 후보는 파트별 마디 수·페이지 수가 같고, 인식 음표 수가 300 DPI 후보의 98% 이상이며, 박자 정보가 줄지 않고, 마디 길이·빈 마디·음가·붙임줄 구조 문제가 하나라도 줄면서 다른 항목은 나빠지지 않을 때만 선택합니다. 차이가 불확실하면 300 DPI 결과를 유지합니다. 한 후보가 실패하면 유효한 다른 후보를 사용합니다. 검사 과정은 인식된 음표를 바꾸거나 마디를 쉼표로 임의 보충하지 않습니다. 구조 선택은 실제 정답률 검증을 대신하지 않으며, 원본 대비 잘못된 음높이는 이 검사만으로 판정할 수 없습니다. 여러 악장이 별도 파일로 나온 경우 첫 파일만 반환하지 않고 오류로 남깁니다.

실행 시간·메모리는 늘어납니다. Java 4 GB worker는 기본 한 작업씩 실행하며 이후 업로드는 대기합니다. 작업당 총 제한은 기본 1,200초이고 각 후보에 남은 시간 예산을 나눠 배정합니다. `/etc/default/omr`에서 `OMR_PDF_DPIS=300`으로 기존 단일 경로, `OMR_PDF_DPIS=400`으로 고해상도 단일 경로, `OMR_PDF_DPIS=300,400`으로 비교 경로를 지정할 수 있습니다(1~2개, 200~500). `OMR_TIMEOUT`은 총 제한 초, `OMR_MAX_PARALLEL`은 동시 작업 수(기본 1, 최대 4)입니다. VM RAM을 확인하지 않고 동시 수를 늘리지 마세요. 설정 변경 뒤 서비스를 재시작합니다.

앱에서 `일반 악보` 또는 `코드·가사 악보`를 선택합니다. 후자는 Audiveris의 코드 이름·가사 인식 스위치를 켭니다. 코드 이름 인식은 Audiveris 기본값이 꺼져 있으므로, 코드가 없는 악보에서는 `일반 악보`를 선택하세요. 두 유형 모두 원본 PDF를 보존하며 변환 결과는 검토가 필요한 초안입니다. 설정 근거: [Audiveris book parameters](https://audiveris.github.io/audiveris/_pages/guides/main/book_parameters/).

한글 가사를 읽으려면 VM에 Audiveris가 사용할 `kor` OCR 데이터를 설치하고 `/etc/default/omr`에 `OMR_OCR_LANGUAGES=kor+eng`를 설정한 뒤 `sudo systemctl restart omr.service`를 실행합니다. 설치한 OCR 언어만 지정하세요. 언어 파일의 위치와 형식은 [Audiveris OCR languages](https://audiveris.github.io/audiveris/_pages/guides/main/languages/)를 따릅니다. 새 `update.sh`가 기존 서비스에도 `EnvironmentFile` 설정을 추가합니다.

변환 재현 자료는 `/opt/omr/jobs/<job-id>/out/`에 있습니다. `dpi-300/`, `dpi-400/`(이미지는 `original/`)에 각각 `audiveris.log`, `.omr`, `.mxl`을 보존하고, 선택된 결과와 로그를 `out/`에 복사합니다. `recognition.json`에는 각 후보의 검사 결과·실행 시간·선택 근거를 남깁니다. 인증된 `GET /jobs/<id>/diagnostics`로도 이 JSON을 받을 수 있습니다. 기본 보관 시간은 완료 후 6시간입니다. `-save`를 사용하므로 Audiveris GUI에서 `.omr`을 열어 실제 인식 오류를 확인할 수 있습니다.

기존 서비스 업데이트는 `omr_server.py`와 **새 `update.sh`**를 VM에서 업로드 가능한 같은 디렉터리에 올리고 실행합니다. 예를 들어 `/root`에 올렸다면 `bash /root/update.sh`, 파일시스템 루트 `/`에 올렸다면 `bash /update.sh`입니다. 스크립트와 Python 파일이 다른 곳에 있다면 `bash /root/update.sh /`처럼 업로드 디렉터리를 인자로 지정합니다. 스크립트가 파일을 `/opt/omr`로 복사하고 옵션 환경 파일을 읽는 systemd drop-in을 추가한 뒤 서비스를 재시작합니다. health에서 새 pipeline 식별자까지 확인합니다. 추가 Python 패키지는 필요하지 않습니다. `compare_musicxml.py`는 변환 서비스에 필요하지 않으며, VM에서 비교할 때만 같은 업로드 디렉터리에 함께 올리면 설치됩니다. 기존 `~/update-omr.sh`가 아닌 새 `update.sh`를 실행하세요. 다중 해상도 변환에는 앱 재설치가 필요하지 않습니다. 앞서 추가한 앱의 일반/코드·가사 선택 UI가 없다면 그 UI용 앱 업데이트는 별도로 필요합니다. 이 업데이트 스크립트는 기존 systemd 서비스를 전제로 합니다.

수동 수정한 기준 MusicXML이 생기면 로컬에서는 `python server/omr/compare_musicxml.py reference.mxl converted.mxl`, VM에 설치했다면 `python3 /opt/omr/compare_musicxml.py reference.mxl converted.mxl`로 마디별 음높이·음가 겹침을 측정합니다. 이 수치는 성부, 붙임줄, 가사, 조판까지 포함한 전체 정답률이 아닙니다. 같은 악보의 변환 설정을 비교하는 진단 지표로 사용하세요.

앱 기본 주소는 `http://34.10.15.222:8080`, 토큰은 `piano-omr-dev` 입니다. VM을 끄면 외부 IP가 바뀌므로 `OmrConvertConfig.defaultBaseUrl`을 고칩니다.
