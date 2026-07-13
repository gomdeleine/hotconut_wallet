FLUTTER_BIN ?= fvm flutter
DART_BIN ?= fvm dart

format:
	$(DART_BIN) format . --line-length 120

ready:
	$(DART_BIN) run build_runner clean && $(DART_BIN) run build_runner build --delete-conflicting-outputs && $(DART_BIN) run realm generate && $(FLUTTER_BIN) pub run slang

slang:
	$(DART_BIN) pub run slang

ios-mainnet:
	$(FLUTTER_BIN) build ios --flavor mainnet --release --dart-define=USE_FIREBASE=true

ios-mainnet-appstore:
	$(FLUTTER_BIN) build ipa --flavor mainnet --release --dart-define=USE_FIREBASE=true --export-method app-store

aos-mainnet:
	$(FLUTTER_BIN) build appbundle --flavor mainnet --release --dart-define=USE_FIREBASE=true

ios-regtest:
	$(FLUTTER_BIN) build ios --flavor regtest --release

aos-regtest:
	$(FLUTTER_BIN) build appbundle --flavor regtest --release

# fastlane
pre-deploy: 
	fastlane pre_deploy

fastlane-mainnet:
	cd android && caffeinate -dimsu bundle exec fastlane release_android_mainnet && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_mainnet skip_prep:true

fastlane-regtest:
	cd android && caffeinate -dimsu bundle exec fastlane release_android_regtest && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_regtest skip_prep:true
	
