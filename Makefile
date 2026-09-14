SWIFT_PACKAGES := packages/ContextCoreKit packages/AppleIntelligenceKit packages/ContextCaptureKit packages/DaylineProductKit
SWIFT_CHECK_PATHS := App AppUITests packages/ContextCoreKit packages/AppleIntelligenceKit packages/ContextCaptureKit packages/DaylineProductKit packages/ContextCoreFFIKit/Sources/ContextCoreFFIKit packages/ContextCoreFFIKit/Tests
SWIFT_ENV := CLANG_MODULE_CACHE_PATH=$(CURDIR)/.build/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=$(CURDIR)/.build/swift-module-cache
APP_PROJECT := Dayline.xcodeproj
APP_SCHEME := Dayline
ARCHIVE_PATH := build/Dayline.xcarchive
EXPORT_DIR := build/export
ASC_VENV := scripts/.venv
ASC_PYTHON := $(ASC_VENV)/bin/python
EXPORT_OPTIONS := build/ExportOptions.plist
BUNDLE_ID ?= com.dayline.Dayline
ASC_PROFILE_NAME ?= Dayline App Store
MARKETING_VERSION ?= 0.1.0
BUILD_NUMBER ?= 1
CONTRACTS_VENV := contracts/.venv

.PHONY: help ci quality architecture duplication contracts-venv contracts-check rust-format rust-lint rust-check rust-test rust-build ffi-xcframework ffi-check swift-format swift-format-check swift-lint swift-check swift-test swift-build project app-build app-test export-options archive export-ipa asc-venv asc-dev-venv release-tools-format release-tools-format-check release-tools-lint release-tools-typecheck release-tools-test release-tools-build release-tools-ci asc-status asc-profile asc-build validate-ipa upload release-dry-run release-upload clean

help: ## 利用できるターゲットを表示する
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z_-]+:.*## / {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

ci: architecture rust-format rust-lint rust-check rust-test rust-build ffi-check swift-format-check swift-lint swift-check swift-test swift-build app-build app-test ## blocking CIと同じ検証を実行する

quality: duplication ## 警告扱いの横断的品質検査を実行する

architecture: ## 依存方向と責務境界を検証する
	scripts/check-architecture.sh

duplication: ## コード重複を検出する（CIでは警告扱い）
	npx --yes jscpd@4 --config .jscpd.json

contracts-venv: ## JSON Schema検証環境を作成する
	python3 -m venv $(CONTRACTS_VENV)
	$(CONTRACTS_VENV)/bin/pip install -r contracts/requirements.txt

contracts-check: ## Contract schemaとfixtureを検証する
	$(CONTRACTS_VENV)/bin/check-jsonschema --check-metaschema contracts/context-event.schema.json
	$(CONTRACTS_VENV)/bin/check-jsonschema --check-metaschema contracts/semantic-artifact.schema.json
	$(CONTRACTS_VENV)/bin/check-jsonschema --check-metaschema contracts/context-bundle.schema.json
	$(CONTRACTS_VENV)/bin/check-jsonschema --check-metaschema contracts/action-proposal.schema.json
	$(CONTRACTS_VENV)/bin/check-jsonschema \
		--schemafile contracts/context-event.schema.json \
		contracts/fixtures/context-event-v1.json
	$(CONTRACTS_VENV)/bin/check-jsonschema \
		--schemafile contracts/semantic-artifact.schema.json \
		contracts/fixtures/semantic-artifact-v1.json
	$(CONTRACTS_VENV)/bin/check-jsonschema \
		--schemafile contracts/context-bundle.schema.json \
		contracts/fixtures/context-bundle-v1.json
	$(CONTRACTS_VENV)/bin/check-jsonschema \
		--schemafile contracts/action-proposal.schema.json \
		contracts/fixtures/action-proposal-v1.json
	@! $(CONTRACTS_VENV)/bin/check-jsonschema \
		--schemafile contracts/context-event.schema.json \
		contracts/fixtures/invalid/context-event-zero-retention-v1.json
	@! $(CONTRACTS_VENV)/bin/check-jsonschema \
		--schemafile contracts/context-event.schema.json \
		contracts/fixtures/invalid/context-event-kind-payload-mismatch-v1.json
	@! $(CONTRACTS_VENV)/bin/check-jsonschema \
		--schemafile contracts/semantic-artifact.schema.json \
		contracts/fixtures/invalid/semantic-artifact-empty-sources-v1.json
	@! $(CONTRACTS_VENV)/bin/check-jsonschema \
		--schemafile contracts/context-bundle.schema.json \
		contracts/fixtures/invalid/context-bundle-zero-budget-v1.json
	@! $(CONTRACTS_VENV)/bin/check-jsonschema \
		--schemafile contracts/action-proposal.schema.json \
		contracts/fixtures/invalid/action-proposal-destructive-without-confirmation-v1.json
	@! $(CONTRACTS_VENV)/bin/check-jsonschema \
		--schemafile contracts/action-proposal.schema.json \
		contracts/fixtures/invalid/action-proposal-empty-sources-v1.json

rust-format: ## Rustのフォーマットを検証する
	cd rust && cargo fmt --all --check

rust-lint: ## RustをClippyで検証する
	cd rust && cargo clippy --workspace --all-targets -- -D warnings

rust-check: ## Rustを型検査する
	cd rust && cargo check --workspace --all-targets

rust-test: ## Rustの単体テストを実行する
	cd rust && cargo test --workspace

rust-build: ## Rustをreleaseビルドする
	cd rust && cargo build --workspace --release

ffi-xcframework: ## Rust/Swift境界のXCFrameworkとSwift bindingを生成する
	scripts/build-context-xcframework.sh

ffi-check: ffi-xcframework ## 生成済みFFI artifactを検証する
	@test -f packages/ContextCoreFFIKit/.artifacts/ContextCoreFFI.xcframework/Info.plist
	@test -f packages/ContextCoreFFIKit/.generated/ContextCoreFFIGenerated/ContextCoreFFI.swift
	@! rg --quiet 'use "_Builtin_' packages/ContextCoreFFIKit/.artifacts/ContextCoreFFI.xcframework
	$(SWIFT_ENV) swift test --package-path packages/ContextCoreFFIKit --parallel

swift-format: ## Swiftソースを整形する
	swift format format --recursive --in-place $(SWIFT_CHECK_PATHS)

swift-format-check: ## Swiftのフォーマットを検証する
	swift format lint --recursive --strict $(SWIFT_CHECK_PATHS)

swift-lint: ## SwiftLintを実行する
	swiftlint lint --strict --no-cache

swift-check: ## Swiftパッケージを型検査する
	@set -e; for package in $(SWIFT_PACKAGES); do \
		echo "Type checking $$package"; \
		$(SWIFT_ENV) swift build --package-path "$$package"; \
	done

swift-test: ## Swiftの単体テストを実行する
	@set -e; for package in $(SWIFT_PACKAGES); do \
		echo "Testing $$package"; \
		$(SWIFT_ENV) swift test --package-path "$$package" --parallel; \
	done

swift-build: ## Swiftパッケージをreleaseビルドする
	@set -e; for package in $(SWIFT_PACKAGES); do \
		echo "Building $$package"; \
		$(SWIFT_ENV) swift build --package-path "$$package" -c release; \
	done

project: ## Xcodeプロジェクトを生成する
	xcodegen generate

app-build: ffi-xcframework project ## 実Rust FFIをリンクしてiOS Appを署名なしでビルドする
	xcodebuild build -project $(APP_PROJECT) -scheme $(APP_SCHEME) \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath build/local CODE_SIGNING_ALLOWED=NO

app-test: ffi-xcframework project ## 実Rust FFIをリンクしdeterministic fakeでiOS UI testを実行する
	xcodebuild test -project $(APP_PROJECT) -scheme $(APP_SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
		-derivedDataPath build/tests CODE_SIGNING_ALLOWED=NO

check-release-config:
	@test -n "$${APPLE_TEAM_ID:-}" || (echo "APPLE_TEAM_ID is required" && exit 1)

export-options: check-release-config ## SecretからApp Store export設定を生成する
	@APPLE_TEAM_ID="$${APPLE_TEAM_ID}" BUNDLE_ID="$(BUNDLE_ID)" \
		ASC_PROFILE_NAME="$(ASC_PROFILE_NAME)" \
		python3 scripts/render_export_options.py --output $(EXPORT_OPTIONS)

archive: ffi-xcframework project check-release-config ## App Store提出用archiveを作成する
	@xcodebuild archive -project $(APP_PROJECT) -scheme $(APP_SCHEME) \
		-destination 'generic/platform=iOS' -archivePath $(ARCHIVE_PATH) \
		DAYLINE_TEAM_ID="$${APPLE_TEAM_ID}" \
		PRODUCT_BUNDLE_IDENTIFIER="$(BUNDLE_ID)" \
		MARKETING_VERSION="$(MARKETING_VERSION)" \
		CURRENT_PROJECT_VERSION="$(BUILD_NUMBER)"

export-ipa: archive export-options ## archiveからApp Store用IPAを書き出す
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_DIR) -exportOptionsPlist $(EXPORT_OPTIONS)

asc-venv: ## App Store Connect CLIの仮想環境を作成する
	python3 -m venv $(ASC_VENV)
	$(ASC_VENV)/bin/pip install -r scripts/requirements-asc.txt

asc-dev-venv: ## App Store Connect CLIの開発・検証環境を作成する
	python3 -m venv $(ASC_VENV)
	$(ASC_VENV)/bin/pip install -r scripts/requirements-dev.txt

release-tools-format: ## App Store Connect CLIを整形する
	$(ASC_VENV)/bin/ruff format scripts

release-tools-format-check: ## App Store Connect CLIのformatを検証する
	$(ASC_VENV)/bin/ruff format --check scripts

release-tools-lint: ## App Store Connect CLIをlintする
	$(ASC_VENV)/bin/ruff check scripts

release-tools-typecheck: ## App Store Connect CLIを型検査する
	$(ASC_VENV)/bin/mypy scripts

release-tools-test: ## App Store Connect CLIのunit testを実行する
	PYTHONPATH=scripts $(ASC_PYTHON) -m unittest discover -s scripts/tests

release-tools-build: ## App Store Connect CLIをcompile検証する
	$(ASC_PYTHON) -m compileall -q scripts

release-tools-ci: release-tools-format-check release-tools-lint release-tools-typecheck release-tools-test release-tools-build ## Release CLIのblocking検証を実行する

check-asc:
	@test -n "$${ASC_KEY_ID:-}" || (echo "ASC_KEY_ID is required" && exit 1)
	@test -n "$${ASC_ISSUER_ID:-}" || (echo "ASC_ISSUER_ID is required" && exit 1)
	@test -x "$(ASC_PYTHON)" || (echo "Run make asc-venv first" && exit 1)

asc-status: check-asc ## App Store Connect上の状態を表示する
	$(ASC_PYTHON) scripts/asc.py status

asc-profile: check-asc ## 配布用provisioning profileを取得する
	$(ASC_PYTHON) scripts/asc.py profile

asc-build: check-asc ## 最新の有効なbuildを編集可能versionへ紐付ける
	$(ASC_PYTHON) scripts/asc.py build

check-ipa:
	@test -f "$(EXPORT_DIR)/Dayline.ipa" || (echo "Exported IPA is missing" && exit 1)

validate-ipa: check-asc check-ipa ## IPAをApple側で検証する（アップロードしない）
	@API_PRIVATE_KEYS_DIR="$${ASC_PRIVATE_KEYS_DIR}" xcrun altool --validate-app \
		--type ios --file $(EXPORT_DIR)/Dayline.ipa \
		--apiKey "$${ASC_KEY_ID}" --apiIssuer "$${ASC_ISSUER_ID}"

upload: check-asc check-ipa ## IPAをApp Store Connectへアップロードする
	@API_PRIVATE_KEYS_DIR="$${ASC_PRIVATE_KEYS_DIR}" xcrun altool --upload-app \
		--type ios --file $(EXPORT_DIR)/Dayline.ipa \
		--apiKey "$${ASC_KEY_ID}" --apiIssuer "$${ASC_ISSUER_ID}"

release-dry-run: ## archiveからApple検証まで順番に実行する
	$(MAKE) asc-venv
	$(MAKE) asc-profile
	$(MAKE) export-ipa
	$(MAKE) validate-ipa

release-upload: ## archive、upload、build紐付けを順番に実行する
	$(MAKE) asc-venv
	$(MAKE) asc-profile
	$(MAKE) export-ipa
	$(MAKE) upload
	$(MAKE) asc-build

clean: ## ローカル生成物を削除する
	cd rust && cargo clean
	@set -e; for package in $(SWIFT_PACKAGES); do swift package --package-path "$$package" clean; done
