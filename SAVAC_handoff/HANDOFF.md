# SAVAC REDCap 분석 - 작업 인수인계

이 파일은 이전 세션(클라우드)에서 한 작업을 새 세션으로 넘기기 위한 메모입니다.
같은 번들 파일 아래쪽에 코드와 매칭 표 원본이 모두 들어 있습니다.

## 0. 새 세션에서 먼저 할 일

1. 이 번들 파일에서 "FILE: 경로" 표시 줄부터 "END FILE" 표시 줄 사이를 각각 해당 경로의
   파일로 저장한다 (번들 맨 위 설명 참고). 내용은 한 글자도 바꾸지 않는다.
   - `SAVAC_hospital.Rmd`
   - `SAVAC_community.Rmd`
   - `varmap/SAVAC_HOS_varmap_MRCG.csv`
   - `varmap/SAVAC_HOS_varmap_PGI.csv`
   - (이 메모 자체는 `HANDOFF.md`로 저장)
2. RMD는 `varmap/` 폴더를 RMD와 같은 위치에서 찾는다. xlsx가 없으면 같은 이름의 CSV를 읽는다.
   CSV를 엑셀에서 열어 xlsx로 저장해도 된다(시트 이름은 `varmap`이어야 함).
3. 지금까지 **가짜 데이터로만 테스트**했다. 실제 REDCap 데이터로 RMD를 처음부터 실행해서
   오류와 결과를 확인하는 것이 다음 단계다.

## 1. 사용자와 작업 방식

- 대화는 한국어, **코드 주석은 항상 영어**.
- 개수 확인은 함수/요약보다 "한 줄씩 쳐서 확인"하는 스타일을 선호한 적이 있음
  (단, 최종 요약표와 워드 리포트도 원함).
- 기존에 쓰던 리포트 스타일: officer + flextable로 워드 출력, `DocStyle.docx` 템플릿,
  heading 1/2 스타일, Total 행 굵게 + 위에 굵은 선. (참고: MLW Community Data Status Report Rmd)
- 사용자의 기존 Community 리포트 Rmd에는 MLW REDCap API 토큰이 코드에 그대로 적혀 있었음
  → `.Renviron`으로 옮기라고 안내함.

## 2. 데이터 접근

- REDCap API: `https://ivirdc.ivi.int/api/`
- 토큰: `C:/Users/saehyeun.song/Documents/.Renviron` 에 저장, `readRenviron()`으로 읽음
  - `SAVAC_MLW_HOS_TOKEN_IVI`, `SAVAC_MLW_COMM_TOKEN_IVI`
  - `SAVAC_PGI_HOS_TOKEN_PID181`, `SAVAC_PGI_COMM_TOKEN_PID180`
  - `SAVAC_MRCG_HOS_TOKEN_IVI`, `SAVAC_MRCG_COMM_TOKEN_IVI`
- 패키지: REDCapR(`redcap_read`, `redcap_metadata_read`), dplyr, tidyr, purrr, lubridate,
  readxl, officer, flextable, writexl
- raw와 label을 둘 다 받고, label 데이터는 raw와 **같은 행 번호**로 subset한다
  (label에서는 이벤트명이 라벨로 바뀌어 필터가 안 되기 때문).

## 3. Hospital (`SAVAC_hospital.Rmd`)

### 사이트별 구조 (중요)
- **MLW**: 질환별 form. RHD는 `rhd` + `rhd_followup` form, 이벤트 `rhd_arm_1`. MLW가 기준(reference).
- **PGI**: MLW와 거의 같음. 차이:
  - `rh_adm_dt` 없음 → `rh_enrol_from`(1 OPD / 2 IPD)에 따라 `rh_adm_opd_dt` / `rh_adm_ipd_dt`
  - PGI에만: `rh_enrol_from`, `rh_opd_visit_dt`, `rh_enrol_opd`, `rh_visit_reason`, `rh_visit_reason_x`
  - `rhf_disch_dt_na` 코드 3(OPD 등록), `rhf_rtn` 코드 3(waiver) 추가 → 표에 `[code 3]`으로 표시
- **MRCG**: 공통 CRF 모듈 구조로 완전히 다름(cda_ 인구학, phr_ 병력, cin_ 검사, rhd_ RHD CRF 15개,
  adm_ 입원/결과, fwu_ 추적). RHD 대상은 `rhd_ppc_adm___1~10` 중 하나라도 1인 레코드.
  나이 `cda_dob_cal_yrs`(DOB→입원일 계산), 동의일 `cda_dt_con`.

### 섹션 구성
1-4. 로드, RHD 데이터셋(MLW/PGI: `rhd_arm_1` + `rh*` 변수만 / MRCG: rhd_ppc_adm 조건, 전체 변수), 중복 확인
5. 개수 한 줄씩 확인
   - 등록: MLW/PGI `rh_ic` 또는 `rh_no_ic` 응답 / MRCG `rhd_ppc_adm` 아무거나 1
   - f/u: MLW/PGI `rhf_disch_dt` 또는 `rhf_disch_dt_na` / MRCG `fwu_dof` 또는 `fwu_tof_up`
6. 요약표: `n_total`(전체 HOS 고유 record), `n_enrolled_rhd`, `n_followup`, `pct_followup`,
   `rh_ic`/`rh_no_ic` 응답별 개수(고유 record 기준)
7. RHD 변수 사이트별 비교
   - 7.1 설정: `var_prefix <- "^rh"`, `target_event`, `varmap_file`(PGI, MRCG), `low_threshold <- 90`
   - 7.2 함수: 변수 타입 분류(Cate/Check/Cont/Calc/Date/Time/Text), branching logic → R 변환,
     타입별 요약(`summarise_var`), flextable
   - 7.3 **Harmonise**: varmap 파일로 PGI/MRCG를 MLW 변수명·코딩으로 변환
     (record당 1행: checkbox는 아무 행에서나 체크면 1, 나머지는 첫 non-missing).
     식이 비어 있는데 site_fields만 적힌 행을 경고 목록으로 보여줌.
   - 7.4 분석 행, 7.5 통합 Data Dictionary(사이트 간 차이 `issues`), 7.6 통합 선택지 기준으로 값 채우기
8. RHD 케이스 요약: 사이트별 케이스 수, 등록일 범위(`rh_ic_dt`), 나이대별 수, 사이트별 ID 리스트
   → `SAVAC_HOS_RHD_cases_YYYYMMDD.xlsx`
9. 워드 리포트 `SAVAC_HOS_RHD_report_YYYYMMDD.docx`: 9.1 케이스 요약 표 → 9.2 변수 비교
   (사이트 개요, dictionary 차이, 완성도 개요, 변수별 상세)
10. 엑셀 저장(선택)

### varmap 파일 규칙
열: `ref_field, ref_form, ref_label, ref_type, ref_choices, match, site_expr, row_filter,
site_fields, site_form, site_label, site_choices, note, confirmed`
- RMD는 `site_expr`만 실행한다. 다른 열은 참고용.
- `site_expr`: 사이트 데이터에서 MLW 코딩 값을 만드는 R 식. 체크박스 필드명만 쓰면 옵션 전체 복사.
  헬퍼: `to_date(x)`, `yn12(x)`(1/0 → 1 Yes/2 No), `chk(cond)`(→ 1/0), `lab("field", x)`(코드→라벨)
- `row_filter`: 그 조건을 만족하는 행만 사용 (MRCG follow-up은 `fwu_tof_up %in% 1` = 28일)

### MRCG 매칭에서 정한 것 / 남은 것
- MUAC: MLW mm, MRCG cm → ×10
- `rh_disch_dt`: MRCG `adm_dod_dd`(퇴원일, 사망 시 사망일) → 결과가 사망(`adm_out_dis`=5)이면 NA
- `rh_ic`: 본인 또는 부모 동의 있으면 1, 둘 다 0이면 2 (MRCG에 waiver 없음)
- `rh_eval`: MRCG `cin_eco_rts`는 단일 선택, 중증도 변수 없음
- `rh_med`: Benzathine→IM penicillin, Oral pen V→oral penicillin/Penicillin V, Erythromycin→Macrolide,
  Warfarin→Anti-coagulants, Other cardiac→diuretics/anti-hypertensives/other (Approximate)
- 진단(`rh_dgn_*`) ← `rhd_dcy_rhd` 1~4
- **미정: `rh_arfhist`** (MLW는 Yes를 출처별 1~3으로 나눔, MRCG `phr_arf`는 Yes/No) → `site_expr` 비워 둠
- 사용자가 varmap을 한 번 고쳤다가 "처음 버전이 맞다"고 해서 처음 버전 유지 중

### 나이
- 나이대: `<5`, `5-14`, `15-18`, `19+`, `Missing` (만 나이 = floor, 15세는 15-18)
- "어린이/young child" 기준은 프로토콜 확인 필요 (임상적으로 young child는 보통 <5세,
  RHD 연구의 children은 보통 5-14세). 한때 "요약은 14세 이하만"이라고 했다가 **취소함** → 현재 전체 나이.

## 4. Community (`SAVAC_community.Rmd`)

- baseline 이벤트(MLW/PGI `baseline_arm_1`, **MRCG `baseline_q0_arm_1`**)의 **repeat 아닌 행**에서
  `bs_` 변수와 나이를 가져와 `trigger_arm_1` 레코드에 붙임 (`culture_analysis` repeat 행 때문에
  repeat 행은 제외해야 함).
- 나이 순서: `bs_dob`(MRCG는 `bs_dob_known == 1`일 때만) ~ `bs_ic_dt` → `bs_age_calc`
  → `bs_age_year`(+month, month만 있으면 month/12) → `bs_est_dob_yrs`(MRCG 추정 나이). `age_source`에 출처 표시.
  MRCG `bs_dob`는 딕셔너리에서 Identifier로 지정돼 export에서 비어 옴. MRCG `bs_age_calc`는 DOB~`bs_visit_dt` 계산,
  DOB 모르면(`bs_dob_known = 99`) 나이는 `bs_est_dob_yrs`에만 있음. PGI `bs_age_calc`는 DOB/age_year/month 모두 반영.
- **MRCG Community 레코드는 REDCap API가 아닌 원본 CSV에서 읽음** (REDCap import가 제대로 안 됨):
  `csv_file["MRCG_COMM"]` = Box 경로의 `LEO31452SavacCommuni_DATA_2026-08-14_0943(in).csv`.
  메타데이터는 API. 메타데이터로 형식 변환(코드/숫자 → numeric, 날짜 → Date, YYYY-MM-DD와 DD/MM/YYYY 모두),
  label 데이터는 `raw_to_label()`로 생성. 인코딩이 깨지면 `csv_encoding <- "latin1"`.
- MRCG·PGI Community 딕셔너리 받음 (MLW Community 딕셔너리는 아직 없음). 변수명 비교:
  trigger_event는 같은 이름 51개(PGI만 2, MRCG만 14), baseline_visit_individual은 같은 이름 51개(PGI만 31, MRCG만 26).
- MRCG `record_id`는 숫자형, MLW는 문자형 → 합칠 때 문자형으로 통일.
- 나이대별 사이트 요약표(`age_summary`, n (%) 버전) + 사이트별 나이대 ID 리스트(`age_ids`, 엑셀 시트 ids_*).
- 8. 모든 항목별 사이트 비교 (Hospital 7번과 같은 함수): trigger 데이터셋의 모든 변수,
  변수명으로 사이트 매칭(varmap 없음). trigger 변수는 trigger 행 기준, `bs_` 변수는 레코드당 1번.
- 9. 워드 `SAVAC_COMM_report_YYYYMMDD.docx` (나이대 요약 + ID 리스트 → 변수 비교),
  10. 엑셀 `SAVAC_comm_age_summary_*.xlsx`, `SAVAC_comm_variables_summary_*.xlsx`.
- Community 딕셔너리는 아직 못 받음: MRCG 등 변수명이 다르면 Hospital처럼 varmap이 필요할 수 있음.

## 5. 다음 단계 (제안)

1. 실제 데이터로 `SAVAC_hospital.Rmd` 전체 실행, 오류 수정
2. 7.3 harmonise 로그와 "식 없는 매칭 행" 확인
3. `rh_arfhist` 비교 방식 결정
4. 어린이 나이 기준 결정 후 필요하면 요약에 반영
5. 워드 리포트 레이아웃 실제 데이터로 확인 (`DocStyle.docx`에 heading 3 스타일이 없으면 오류 → heading 2로)
