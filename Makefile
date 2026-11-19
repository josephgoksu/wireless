# make            build, install to ~/Applications, launch
# DEVELOPMENT_TEAM=XXXXXXXXXX make   widgets need a signed build
DEVELOPMENT_TEAM ?= $(shell security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject | sed -n 's/.*OU=\([A-Z0-9]*\).*/\1/p')
export DEVELOPMENT_TEAM
APP = build/Build/Products/Release/Wireless.app

run: install
	open ~/Applications/Wireless.app

install: build
	rm -rf ~/Applications/Wireless.app && mkdir -p ~/Applications && cp -R $(APP) ~/Applications/

build:
	xcodegen --quiet
	xcodebuild -project Wireless.xcodeproj -scheme Wireless -configuration Release -derivedDataPath build -allowProvisioningUpdates -quiet build

icon:
	swiftc -parse-as-library scripts/icon.swift Shared/Parts.swift Shared/Stations.swift -o build/icon && build/icon App/Assets.xcassets/AppIcon.appiconset

.PHONY: run install build icon release

release:
	scripts/release.sh
