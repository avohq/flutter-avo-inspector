import 'package:flutter/material.dart';

import 'package:avo_inspector/avo_inspector.dart';

void main() {
  runApp(MyApp());
}

AvoInspector? avoInspector;

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key) {
    AvoInspector.create(
            apiKey: "FCAUwJiSGWmI7nJaqtNr",
            env: AvoInspectorEnv.dev,
            appVersion: "1.0",
            appName: "Flutter test")
        .then((inspector) {
      avoInspector = inspector;
      avoInspector
          ?.trackSchemaFromEvent(eventName: "App Open", eventProperties: {});
    });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    AvoInspector.shouldLog = true;

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
    avoInspector?.trackSchemaFromEvent(
        eventName: "Counter++", eventProperties: {"counter": _counter});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
