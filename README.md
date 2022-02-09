# Avo Inspector

# Installation

With Flutter:

 $ flutter pub add avo_inspector

This will add a line like this to your package's pubspec.yaml (and run an implicit flutter pub get):

```
dependencies:
  avo_inspector: ^0.9.9
```

## Import it

Now in your Dart code, you can use:

import 'package:avo_inspector/avo_inspector.dart';

# Initialization

Obtain the API key at [Avo.app](https://www.avo.app/welcome)

```dart
import 'package:avo_inspector/avo_inspector.dart';

AvoInspector avoInspector = await AvoInspector.create(
      apiKey: "my_key",
      env: AvoInspectorEnv.dev,
      appVersion: "1.0",
      appName: "Hello Flutter");
```

# Enabling logs

Logs are enabled by default in the dev mode and disabled in prod mode.

```dart
AvoInspector.shouldLog = true;
```

# Sending event schemas for events reported outside of Avo Functions

Whenever you send tracking event call one of the following methods:

Read more in the [Avo documentation](https://www.avo.app/docs/implementation/devs-101#inspecting-events)

This method gets actual tracking event parameters, extracts schema automatically and sends it to the Avo Inspector backend.
Just call this method at the same place you call your analytics tools' track methods with the same parameters.

```dart
avoInspector.trackSchemaFromEvent(
            eventName: "Event name",
            eventProperties: {
                "String Prop": "Prop Value",
                "Float Prop": 1.0,
                "Boolean Prop": true});
```

# Batching control

In order to ensure our SDK doesn't have a large impact on performance or battery life it supports event schemas batching.

Default batch size is 30 and default batch flush timeout is 30 seconds.
In development mode batching is disabled.

```javascript
AvoBatcher.batchSizeThreshold = 10;
AvoBatcher.batchFlushSecondsThreshold = 10;
```

## Author

Avo (https://www.avo.app), friends@avo.app

## License

AvoInspector is available under the MIT license.
