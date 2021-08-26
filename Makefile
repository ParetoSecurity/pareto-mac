test:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -configuration Debug -resultBundlePath test.xcresult -destination platform=macOS test 

build:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -configuration Debug -destination platform=macOS build

archive-debug:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -destination platform=macOS archive -archivePath app.xcarchive -configuration Debug -allowProvisioningUpdates
	xcodebuild -exportArchive -archivePath app.xcarchive -exportPath Export -exportOptionsPlist exportOptionsDev.plist

archive-release:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -destination platform=macOS archive -archivePath app.xcarchive -configuration Release -allowProvisioningUpdates
	xcodebuild -exportArchive -archivePath app.xcarchive -exportPath Export -exportOptionsPlist exportOptions.plist

dmg:
	create-dmg --overwrite Export/Pareto\ Security.app Export && mv Export/*.dmg ParetoSecurity.dmg

lint:
	swiftlint .

fmt:
	swiftformat --swiftversion 5 .
	swiftlint . --fix

notarize:
	xcrun altool --notarize-app -f ParetoSecurity.dmg --primary-bundle-id niteo.co.Pareto