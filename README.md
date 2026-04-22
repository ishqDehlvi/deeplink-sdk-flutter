# Deeplink Flutter SDK

Flutter package for integrating the Deeplink deep-linking service.

## Install

```yaml
dependencies:
  deeplink: ^0.1.0
```

## Setup

In `main.dart`:
```dart
import 'package:deeplink/deeplink.dart';

void main() {
  Deeplink.configure(DeeplinkConfig(
    apiUrl: 'https://api.yourdomain.com',
    sdkKey: 'dlk_pub_xxxxxxxxxxxxxxxx',
  ));
  runApp(const MyApp());
}
```

## Deferred deep link (on first launch)

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final result = await Deeplink.handleFirstLaunch();
    if (result.matched && result.link?.target != null) {
      // router.push(result.link!.target!);
    }
  });
}
```

## Native setup

Also configure platform-specific Universal Links (iOS) and App Links (Android) as described in the Deeplink dashboard. The backend auto-generates `apple-app-site-association` and `assetlinks.json` once you register the app.
