test:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -configuration Debug -resultBundlePath test.xcresult -destination platform=macOS test 

build:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -configuration Debug -destination platform=macOS build

libSetapp:
	wget "https://developer-api.setapp.com/v1/applications/496/kevlar?token=${SETAPP_TOKEN}&type=libsetapp_silicon" -O libsetapp.zip
	unzip libsetapp.zip
	rm libsetapp.zip

archive-debug:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -destination platform=macOS archive -archivePath app.xcarchive -configuration Debug -allowProvisioningUpdates
	xcodebuild -exportArchive -archivePath app.xcarchive -exportPath Export -exportOptionsPlist exportOptionsDev.plist

archive-debug-setapp: libSetapp
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security SetApp" -destination platform=macOS archive -archivePath setapp.xcarchive -configuration Debug -allowProvisioningUpdates
	xcodebuild -exportArchive -archivePath setapp.xcarchive -exportPath SetAppExport -exportOptionsPlist exportOptionsDev.plist
	mv SetAppExport/Pareto\ Security\ SetApp.app SetAppExport/Pareto\ Security.app

archive-release:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -destination platform=macOS archive -archivePath app.xcarchive -configuration Release -allowProvisioningUpdates
	xcodebuild -exportArchive -archivePath app.xcarchive -exportPath Export -exportOptionsPlist exportOptions.plist


archive-release-setapp: libSetapp
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security SetApp" -destination platform=macOS archive -archivePath setapp.xcarchive -configuration Release -allowProvisioningUpdates
	xcodebuild -exportArchive -archivePath setapp.xcarchive -exportPath SetAppExport -exportOptionsPlist exportOptions.plist
	mv SetAppExport/Pareto\ Security\ SetApp.app SetAppExport/Pareto\ Security.app
	
dmg:
	create-dmg --overwrite Export/Pareto\ Security.app Export && mv Export/*.dmg ParetoSecurity.dmg

lint:
	swiftlint .

fmt:
	swiftformat --swiftversion 5 .
	swiftlint . --fix

notarize:
	xcrun notarytool submit ParetoSecurity.dmg --team-id PM784W7B8X --progress --wait

clean:
	rm -rf SourcePackages
	rm -rf libSetapp
	rm -rf Export
	rm -rf SetAppExport