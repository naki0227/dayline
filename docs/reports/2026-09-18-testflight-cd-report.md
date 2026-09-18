# 作業報告書

## 作業日時

2026年09月18日 10時03分51秒 JST

## 作業対象

DaylineのTestFlight CD、`useful-map`署名再利用、App Store Connect CLI。

## 作業目的

署名Secretを複製・公開せず、Daylineの特定commitをTestFlightへ配布できる経路を整える。

## 変更内容

- `com.enludus.Dayline`にMakefileとGitHub Variableを揃えた。
- exact marketing version/build numberのTestFlight処理確認を追加した。
- App Store Connect HTTPエラー本文をログへ出さなくした。
- `useful-map`で実行する専用手動workflowのsourceを追加した。
- Dayline CDの目的をTestFlightとして明確化した。

## 変更したファイル

`Makefile`、`.github/workflows/release.yml`、`scripts/asc.py`、
`scripts/app_store_connect/builds.py`、`scripts/app_store_connect/client.py`、
`scripts/tests/test_testflight.py`、`scripts/tests/test_client.py`、
`deployment/useful-map-dayline-testflight.yml`、`docs/release.md`、
`docs/adr/0007-borrowed-testflight-signing.md`、`docs/TODO.md`、本報告書。

## 変更意図

GitHub Secret値は取得不能なので、既存Secretのあるrepository上でのみ署名する。
以前の`asc-build`は最新の別buildをApp Store公開版へ紐付けるため、TestFlight判定と分離する。

## 設計上の意図

CIと署名、Apple APIを分離し、境界を短いCLIへ限定する。workflowはDaylineの現行
`main`のSHAだけをcheckoutでき、dry-runを既定にする。

## 影響範囲

リリース自動化のみ。録音、Context Engine、DB、契約、アプリUIの振る舞いには影響しない。

## 追加・更新したテスト

対象buildだけを待つこと、異なるversionを無視すること、processing失敗時に停止すること、
HTTPエラー本文を秘匿することのunit testを追加した。

## 実行した確認コマンド

- `DEVELOPER_DIR=/Library/Developer/CommandLineTools make release-tools-ci`: 成功。
- `DEVELOPER_DIR=/Library/Developer/CommandLineTools make -n release-upload`: 順序確認。
- `git diff --check`、`bash -n scripts/build-context-xcframework.sh`、
  `scripts/check-architecture.sh`: 成功。
- Xcode 26.5のライセンス未同意により、ローカル署名archiveは実行していない。

## CIで確認される内容

Release Toolsがformat/lint/typecheck/unit/compileを実行する。Apple App、FFI、
Rust、Swift等は通常の責務別CIで検証する。`useful-map`の専用CDは再度`make ci`を実行する。

## 未解決の課題

- `useful-map`側のworkflow設置・dry-run・実upload結果を確認する必要がある。
- Apple Developer identifier、App Store Connect app recordと内部tester accessは
  Apple側の確認が必要。
- Dayline自身の5 Secretsは未設定。`v*`タグCDは現状使わない。

## 次にやること

専用workflowを`useful-map`へ配置し、現行Dayline SHAでdry-runを実行する。
成功後に明示的なuploadを行い、TestFlight `VALID` buildと内部tester accessを確認する。

## 次回最初に見るべきファイル

`docs/release.md`、`deployment/useful-map-dayline-testflight.yml`、`docs/TODO.md`。

## 引き継ぎ事項

最初に`gh secret list -R naki0227/useful-map`で名前のみ確認する。Secret値を
ログ、issue、artifact、チャットへ出さない。Daylineの`v*`タグを先に押さない。
