# Common tasks. Run from the repository root on macOS with Xcode 16+.
SIMULATOR ?= platform=iOS Simulator,name=iPhone 16
KIT := Packages/BreatheKit

.PHONY: project open kit sim app-test test clean

## Generate BreatheApp.xcodeproj from project.yml (needs `brew install xcodegen`)
project:
	xcodegen generate

## Generate the project and open it in Xcode
open: project
	open BreatheApp.xcodeproj

## BreatheKit unit tests (runs on macOS and Linux)
kit:
	swift test --package-path $(KIT)

## Run every protocol through the engine at simulated speed and check invariants
sim:
	swift run --package-path $(KIT) breathe-sim all --quiet

## App unit tests + UI tests on the iOS Simulator
app-test: project
	xcodebuild test -project BreatheApp.xcodeproj -scheme BreatheApp \
		-destination '$(SIMULATOR)' CODE_SIGNING_ALLOWED=NO

## Everything
test: kit sim app-test

clean:
	rm -rf BreatheApp.xcodeproj $(KIT)/.build
