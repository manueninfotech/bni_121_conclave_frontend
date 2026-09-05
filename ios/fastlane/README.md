fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios ensure_app

```sh
[bundle exec] fastlane ios ensure_app
```

Create the App Store Connect record if it does not exist yet

### ios push_metadata

```sh
[bundle exec] fastlane ios push_metadata
```

Push App Store listing metadata + screenshots (no binary, no submission)

### ios wait_build

```sh
[bundle exec] fastlane ios wait_build
```

Poll until a build finishes App Store Connect processing

### ios submit

```sh
[bundle exec] fastlane ios submit
```

Submit the selected build for App Store review (metadata already pushed)

### ios upload_only

```sh
[bundle exec] fastlane ios upload_only
```

Upload an already-built IPA to TestFlight (no rebuild)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build the Flutter release archive, export a signed IPA, and upload to TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
