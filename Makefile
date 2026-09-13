SWIFT_PACKAGES := packages/ContextCoreKit packages/AppleIntelligenceKit
SWIFT_ENV := CLANG_MODULE_CACHE_PATH=$(CURDIR)/.build/clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=$(CURDIR)/.build/swift-module-cache

.PHONY: help ci quality architecture duplication rust-format rust-lint rust-check rust-test rust-build swift-format swift-format-check swift-lint swift-check swift-test swift-build clean

help: ## 利用できるターゲットを表示する
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z_-]+:.*## / {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

ci: architecture rust-format rust-lint rust-check rust-test rust-build swift-format-check swift-lint swift-check swift-test swift-build ## blocking CIと同じ検証を実行する

quality: duplication ## 警告扱いの横断的品質検査を実行する

architecture: ## 依存方向と責務境界を検証する
	scripts/check-architecture.sh

duplication: ## コード重複を検出する（CIでは警告扱い）
	npx --yes jscpd@4 --config .jscpd.json

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

swift-format: ## Swiftソースを整形する
	swift format format --recursive --in-place packages

swift-format-check: ## Swiftのフォーマットを検証する
	swift format lint --recursive --strict packages

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

clean: ## ローカル生成物を削除する
	cd rust && cargo clean
	@set -e; for package in $(SWIFT_PACKAGES); do swift package --package-path "$$package" clean; done
