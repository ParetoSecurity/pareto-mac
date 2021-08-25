test:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -resultBundlePath test.xcresult -destination platform=macOS test 

build:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -configuration Debug -destination platform=macOS build

archive:
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -configuration Release -destination platform=macOS build
	xcodebuild -project "Pareto Security.xcodeproj" -clonedSourcePackagesDirPath SourcePackages -scheme "Pareto Security" -destination platform=macOS archive -archivePath build/app.xcarchive -configuration Release -allowProvisioningUpdates
	xcodebuild -exportArchive -archivePath build/app.xcarchive -exportPath build/mac -exportOptionsPlist exportOptions.plist

lint:
	swiftlint .

fmt:
	swiftformat --swiftversion 5 .
	swiftlint . --fix