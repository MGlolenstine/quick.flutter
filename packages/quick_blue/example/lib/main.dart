import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quick_blue/quick_blue.dart';

import 'peripheral_detail_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool scanning = false;
  StreamSubscription<BlueScanResult>? _scanResultSubscription;
  StreamSubscription<AvailabilityState>? _availabilitySubscription;

  @override
  void initState() {
    super.initState();

    QuickBlue.availabilityChangeStream.listen((state) {
      debugPrint('Bluetooth state: ${state.toString()}');
    });

    // if (kDebugMode) {
    //   QuickBlue.setLogger(Logger('quick_blue_example'));
    // }
    _scanResultSubscription = QuickBlue.scanResultStream.listen((result) {
      if (result.deviceId.startsWith("AA:AA:AA") &&
          !_scanResults.any((r) => r.deviceId == result.deviceId)) {
        setState(() => _scanResults.add(result));
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _scanResultSubscription?.cancel();
    _availabilitySubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    checkPermissions();
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Simple Echo app'),
        ),
        body: Column(
          children: [
            _buildButtons(),
            const Divider(color: Colors.blue),
            _buildListView(),
          ],
        ),
      ),
      builder: EasyLoading.init(),
    );
  }

  Widget _buildButtons() {
    Widget button;
    if (scanning) {
      button = ElevatedButton(
        child: const Text('stopScan'),
        onPressed: () {
          QuickBlue.stopScan();
          scanning = false;
          setState(() {});
        },
      );
    } else {
      button = ElevatedButton(
        child: const Text('startScan'),
        onPressed: () {
          QuickBlue.startScan();
          scanning = true;
          _scanResults.clear();
          setState(() {});
        },
      );
    }

    return SizedBox(
      width: double.maxFinite,
      child: button,
    );
  }

  final _scanResults = <BlueScanResult>[];

  Widget _buildListView() {
    return Expanded(
      child: ListView.separated(
        itemBuilder: (context, index) => ListTile(
          title: Text(_scanResults[index].name),
          subtitle: Text(_scanResults[index].deviceId),
          onTap: () {
            QuickBlue.stopScan();
            scanning = false;
            setState(() {});
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PeripheralDetailPage(
                  deviceId: _scanResults[index].deviceId,
                ),
              ),
            );
          },
        ),
        separatorBuilder: (context, index) => const Divider(),
        itemCount: _scanResults.length,
      ),
    );
  }

  Future<bool> checkPermissions() async {
    bool allowed = true;
    if (Platform.isAndroid || Platform.isIOS) {
      if (!await Permission.bluetoothScan.isGranted) {
        allowed = allowed &&
            PermissionStatus.granted ==
                await Permission.bluetoothScan.request();
      }
      if (!await Permission.bluetoothConnect.isGranted) {
        allowed = allowed &&
            PermissionStatus.granted ==
                await Permission.bluetoothConnect.request();
      }
    }
    return allowed;
  }
}
