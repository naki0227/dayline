# 作業報告書

## 作業日時

2026年09月20日 18時52分00秒

## 作業対象

Issue #19 のNotion OAuth broker、独立CI/CD、iOS Release build設定、および運用文書。

## 作業目的

Notion client secretをiOSバイナリへ含めず、既存のOAuth clientが利用できるHTTPS
brokerを実装する。TestFlight配布とは独立して検証・配備できる境界も用意する。

## 変更内容

- Cloudflare WorkerとDurable ObjectsによるOAuth session、token exchange、revokeを実装。
- 10分TTL、2分のcompletion再送期間、秘密鍵HMACによるsession開始rate limit、
  4 KiB body上限を実装。
- Notion client secretをWorker secretとして扱い、応答・ログへ出さない構成にした。
- Node 24の責務別CIと`oauth-broker-v*` tagによる独立CDを追加。
- `Makefile`へbrokerの検証、開発起動、配備targetを追加。
- iOS Release archiveへ公開broker URLだけを渡すようにした。
- Notion public connectionを最小権限で作成し、登録済みHTTPS redirectを設定した。
- Cloudflare Worker secretsとGitHub Actions Secrets/Variablesを構成した。秘密値は
  リポジトリ、issue、ログへ保存していない。
- Cloudflare API tokenを対象アカウント1件の`Workers Scripts: Edit`だけに限定した。
- 初回API tokenは自動操作出力への露出を検知して即時失効し、未露出の代替tokenへ
  ローテーションした。失効済みtokenはGitHub/Workerのどちらでも使用していない。
- 実Notion設定で本番Workerを配備し、healthとOAuth session開始契約を確認した。
- `CD / OAuth Broker`を手動実行し、検証、secret同期、配備、health確認が成功した。

## 変更したファイル

- `services/notion-oauth-broker/src/`、`test/`、`wrangler.jsonc`、`package.json`
- `services/notion-oauth-broker/README.md`、`.dev.vars.example`
- `.github/workflows/ci-oauth-broker.yml`、`deploy-oauth-broker.yml`、`release.yml`
- `Makefile`、`.gitignore`、`README.md`
- `docs/notion.md`、`docs/notion-oauth-broker.md`、`docs/privacy.md`
- `docs/architecture.md`、`docs/adr/0008-notion-oauth-broker.md`、`docs/TODO.md`
- `docs/reports/2026-09-20-notion-oauth-broker-report.md`

## 変更意図

公開clientであるiOSにOAuth client secretを置かず、短命なsession capabilityだけで
authorization codeの交換結果を受け取れるようにするため。broker配備をアプリ配布から
分離し、障害や設定変更がTestFlight配布を誘発しないようにした。

## 設計上の意図

HTTP routing、OAuth状態遷移、Notion API、Durable Object永続化、rate-limit policyを
分離した。状態遷移は外部サービスなしでunit testでき、secretを知るのはbrokerのみ。
completionは通信断対策として短時間だけ再送可能にし、その後refresh tokenと生の
revocation capabilityを消去する。

## 影響範囲

Notion OAuthの接続・解除経路、GitHub Actions、Release archiveのbroker URL build設定。
既存のActionProposal確認境界、Notion書き込みpolicy、TestFlight配布処理は変更しない。

## 追加・更新したテスト

- OAuth成功、拒否、期限切れ、open redirect拒否、completion再送、capability照合、revoke。
- Notion token/revoke requestのmethod、Basic認証、version、payload、異常応答。
- rate-limitの正常、上限、window更新、秘密鍵HMAC key derivation。
- ローカルWorker smoke testでhealth、session作成、不正callback、不正completionを確認。

## 実行した確認コマンド

- `npm run format:check`、`npm run lint`、`npm run typecheck`
- `npm test`、`npm run build`
- `npm audit --audit-level=moderate`
- `git diff --check`
- `wrangler dev --local`を使ったHTTP smoke test
- `npx wrangler deploy --var ...`による本番Worker配備
- `curl`による本番`/health`とOAuth session開始契約の検証
- `gh workflow run deploy-oauth-broker.yml --ref main`
- `gh run watch 35503452710 --exit-status`

brokerの全項目は成功。`make`はローカルの未同意Xcode licenseに阻まれたため、同一の
npm commandを個別実行した。commit `cfcff3f`の責務別CI 11本はすべて成功し、
本番CD run `35503452710`も成功した。

## CIで確認される内容

`CI / OAuth Broker`がNode 24でlockfile install、format、lint、typecheck、unit test、
deploy dry-run buildを実行する。既存CIはRust、Swift、FFI、app、contracts、architecture、
release tools、security、警告扱いの重複検査を責務別に実行する。

## 未解決の課題

- 実workspace・実端末での接続、page選択、解除のacceptance test。
- iOS配布はユーザー指示により保留中であり、上記が未完了のためIssue #19はcloseしない。
- GitHub ActionsのNode.js 20互換shim廃止前にactionsの更新を確認する。

## 次にやること

1. 明示的な配布依頼があった時だけ、broker URLを含むiOS buildを配布する。
2. 実端末で接続、workspace/page選択、export確認、disconnectを確認する。
3. acceptance完了後にIssue #19をcloseする。

## 次回最初に見るべきファイル

- `services/notion-oauth-broker/README.md`
- `docs/notion-oauth-broker.md`
- `.github/workflows/deploy-oauth-broker.yml`
- `docs/TODO.md`

## 引き継ぎ事項

最初に`make oauth-broker-ci`を実行し、必要なら本番`/health`も確認する。Notion client
secretはiOS、GitHub Variables、issue、ログへ置かず、GitHub SecretとCloudflare Worker
secretだけに保存する。
`oauth-broker-v*`はbrokerだけを配備し、`v*`はiOS配布なので混同しない。ユーザーの
明示依頼があるまでTestFlight配布は行わない。
