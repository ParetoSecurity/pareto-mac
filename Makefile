SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

test:
	@rm -rf test.xcresult
	NSUnbufferedIO=YES xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -configuration Debug -resultBundlePath test.xcresult -destination platform=macOS test 2>&1 | mint run xcbeautify --report junit
	mv build/reports/junit.xml .

build:
	NSUnbufferedIO=YES xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -configuration Debug -destination platform=macOS build

archive-debug:
	NSUnbufferedIO=YES xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -destination platform=macOS archive -archivePath app.xcarchive -configuration Debug -allowProvisioningUpdates
	NSUnbufferedIO=YES xcodebuild -exportArchive -archivePath app.xcarchive -exportPath Export -exportOptionsPlist exportOptionsDev.plist

archive-debug-setapp:
	NSUnbufferedIO=YES xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security SetApp" -destination platform=macOS archive -archivePath setapp.xcarchive -configuration Debug -allowProvisioningUpdates
	NSUnbufferedIO=YES xcodebuild -exportArchive -archivePath setapp.xcarchive -exportPath SetAppExport -exportOptionsPlist exportOptionsDev.plist
	mv SetAppExport/Pareto\ Security\ SetApp.app SetAppExport/Pareto\ Security.app

archive-release:
	NSUnbufferedIO=YES xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -destination platform=macOS archive -archivePath app.xcarchive -configuration Release -allowProvisioningUpdates
	NSUnbufferedIO=YES xcodebuild -exportArchive -archivePath app.xcarchive -exportPath Export -exportOptionsPlist exportOptions.plist


archive-release-setapp:
	rm -rf SetAppExport
	NSUnbufferedIO=YES xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security SetApp" -destination platform=macOS archive -archivePath setapp.xcarchive -configuration Release -allowProvisioningUpdates
	NSUnbufferedIO=YES xcodebuild -exportArchive -archivePath setapp.xcarchive -exportPath SetAppExport -exportOptionsPlist exportOptions.plist
	mv SetAppExport/Pareto\ Security\ SetApp.app SetAppExport/Pareto\ Security.app

build-release-setapp:
	# rm -f ParetoSecuritySetApp.app.zip
	# rm -rf SetAppExport/Release
	# mkdir -p SetAppExport/Release
	# cp assets/Mac_512pt@2x.png SetAppExport/Release/AppIcon.png
	# cp -vr SetAppExport/Pareto\ Security.app SetAppExport/Release/Pareto\ Security.app
	# cd SetAppExport; ditto -c -k --sequesterRsrc --keepParent Release ../ParetoSecuritySetApp.app.zip
	cp -f assets/Mac_512pt@2x.png AppIcon.png
	zip -u ParetoSecuritySetApp.app.zip AppIcon.png
	rm -f AppIcon.png

dmg:
	create-dmg --overwrite Export/Pareto\ Security.app Export && mv Export/*.dmg ParetoSecurity.dmg

pkg:
	productbuild --scripts ".github/pkg" --component Export/Pareto\ Security.app / ParetoSecurityPlain.pkg
	productsign --sign "Developer ID Installer: Niteo GmbH" ParetoSecurityPlain.pkg ParetoSecurity.pkg

lint:
	mint run swiftlint .

fmt:
	mint run swiftformat --swiftversion 5 .
	mint run swiftlint . --fix

notarize:
	xcrun notarytool submit ParetoSecurity.dmg --team-id PM784W7B8X --progress --wait

clean:
	rm -rf SourcePackages
	rm -rf Export
	rm -rf SetAppExport

sentry-debug-upload:
	sentry-cli --auth-token ${SENTRY_AUTH_TOKEN} upload-dif app.xcarchive --org teamniteo --project pareto-mac

sentry-debug-upload-setapp:
	sentry-cli --auth-token ${SENTRY_AUTH_TOKEN} upload-dif setapp.xcarchive --org teamniteo --project pareto-mac
