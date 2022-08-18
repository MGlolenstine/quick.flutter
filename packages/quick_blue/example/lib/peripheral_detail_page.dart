// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:developer';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quick_blue/quick_blue.dart';

String gssUuid(String code) => '0000$code-0000-1000-8000-00805f9b34fb';

final GSS_SERV__BATTERY = gssUuid('180f');
final GSS_CHAR__BATTERY_LEVEL = gssUuid('2a19');

const WOODEMI_SUFFIX = 'ba5e-f4ee-5ca1-eb1e5e4b1ce0';

const WOODEMI_SERV__COMMAND = '57444d01-$WOODEMI_SUFFIX';
const WOODEMI_CHAR__COMMAND_REQUEST = '57444e02-$WOODEMI_SUFFIX';
const WOODEMI_CHAR__COMMAND_RESPONSE = WOODEMI_CHAR__COMMAND_REQUEST;

const WOODEMI_MTU_WUART = 247;

class PeripheralDetailPage extends StatefulWidget {
  const PeripheralDetailPage({
    Key? key,
    required this.deviceId,
  }) : super(key: key);

  final String deviceId;

  @override
  State<StatefulWidget> createState() {
    return _PeripheralDetailPageState();
  }
}

class _PeripheralDetailPageState extends State<PeripheralDetailPage> {
  bool _written = true;

  @override
  void initState() {
    super.initState();
    QuickBlue.setConnectionHandler(_handleConnectionChange);
    QuickBlue.setServiceHandler(_handleServiceDiscovery);
    QuickBlue.setValueHandler(_handleValueChange);
    QuickBlue.setWrittenHandler(_handleWritten);
  }

  @override
  void dispose() {
    super.dispose();
    QuickBlue.setValueHandler(null);
    QuickBlue.setServiceHandler(null);
    QuickBlue.setConnectionHandler(null);
    QuickBlue.setWrittenHandler(null);
  }

  void _handleConnectionChange(String deviceId, BlueConnectionState state) {
    debugPrint('_handleConnectionChange $deviceId, $state');
  }

  void _handleServiceDiscovery(String deviceId, String serviceId, List<String> characteristicIds) {
    debugPrint('_handleServiceDiscovery $deviceId, $serviceId, $characteristicIds');
  }

  void _handleValueChange(String deviceId, String characteristicId, Uint8List value) {
    debugPrint('_handleValueChange $deviceId, $characteristicId, ${hex.encode(value)}');
  }

  void _handleWritten(bool written) {
    log("Writing finished. $written");
    _written = true;
  }

  final serviceUUID = TextEditingController(text: WOODEMI_SERV__COMMAND);
  final characteristicUUID = TextEditingController(text: WOODEMI_CHAR__COMMAND_REQUEST);
  final binaryCode = TextEditingController(text: hex.encode([0x01, 0x0A, 0x00, 0x00, 0x00, 0x01]));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PeripheralDetailPage'),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ElevatedButton(
                child: const Text('connect'),
                onPressed: () {
                  QuickBlue.connect(widget.deviceId);
                },
              ),
              ElevatedButton(
                child: const Text('disconnect'),
                onPressed: () {
                  QuickBlue.disconnect(widget.deviceId);
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ElevatedButton(
                child: const Text('discoverServices'),
                onPressed: () {
                  QuickBlue.discoverServices(widget.deviceId);
                },
              ),
            ],
          ),
          ElevatedButton(
            child: const Text('setNotifiable'),
            onPressed: () {
              QuickBlue.setNotifiable(widget.deviceId, WOODEMI_SERV__COMMAND, WOODEMI_CHAR__COMMAND_RESPONSE, BleInputProperty.indication);
            },
          ),
          TextField(
            controller: serviceUUID,
            decoration: const InputDecoration(
              labelText: 'ServiceUUID',
            ),
          ),
          TextField(
            controller: characteristicUUID,
            decoration: const InputDecoration(
              labelText: 'CharacteristicUUID',
            ),
          ),
          TextField(
            controller: binaryCode,
            decoration: const InputDecoration(
              labelText: 'Binary code',
            ),
          ),
          ElevatedButton(
            child: const Text('send'),
            onPressed: () {
              var value = Uint8List.fromList(hex.decode(binaryCode.text));
              QuickBlue.writeValue(widget.deviceId, serviceUUID.text, characteristicUUID.text, value, BleOutputProperty.withResponse);
            },
          ),
          ElevatedButton(
            child: const Text('readValue battery'),
            onPressed: () async {
              await QuickBlue.readValue(widget.deviceId, GSS_SERV__BATTERY, GSS_CHAR__BATTERY_LEVEL);
            },
          ),
          ElevatedButton(
            child: const Text('requestMtu'),
            onPressed: () async {
              var mtu = await QuickBlue.requestMtu(widget.deviceId, WOODEMI_MTU_WUART);
              debugPrint('requestMtu $mtu');
            },
          ),
          ElevatedButton(
            child: const Text('test read'),
            onPressed: () async => test_read(),
          ),
          ElevatedButton(
            child: const Text('test write'),
            onPressed: () async => test_write(),
          ),
          ElevatedButton(
            child: const Text('speed test'),
            onPressed: () async => speed_test(),
          )
        ],
      ),
    );
  }

  Future<void> test_read() async {
    QuickBlue.setValueHandler((deviceId, characteristicId, value) {
      log("Read value $value from $deviceId:$characteristicId");
    });
    log("Reading value from ${gssUuid("1337")}:${gssUuid("2000")}");
    QuickBlue.readValue(widget.deviceId, gssUuid("1337"), gssUuid("2000"));
  }

  Future<void> test_write() async {
    int mtu = 250;
    List<int> data = <int>[];
    for (int i = 0; i < mtu; i++) {
      data.add(i);
    }
    _written = false;
    var list = Uint8List.fromList(data);
    log("Writing value to ${gssUuid("1337")}:${gssUuid("3000")}");
    await QuickBlue.writeValue(widget.deviceId, gssUuid("1337"), gssUuid("3000"), list, BleOutputProperty.withoutResponse);
    log("Writing queued.");
    while (!_written) {
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<void> speed_test() async {
    log("Starting 5s speed test");
    int mtu = 1000000;
    List<int> data = <int>[];
    for (int i = 0; i < mtu; i++) {
      data.add(i);
    }
    var list = Uint8List.fromList(data);
    final stopwatch = Stopwatch();
    const test_duration = Duration(seconds: 5);
    stopwatch.start();
    var bytecount = 0;
    // Write only
    while (stopwatch.elapsed < test_duration) {
      _written = false;
      await QuickBlue.writeValue(widget.deviceId, gssUuid("1337"), gssUuid("3000"), list, BleOutputProperty.withoutResponse);
      while (!_written) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
      bytecount += mtu;
    }
    stopwatch.stop();
    var duration = stopwatch.elapsedMilliseconds / 1000.0;
    var rate = bytecount / duration;
    final numberFormat = NumberFormat("##########.##");
    log("Write only throughput: ${numberFormat.format(rate)}bps/ ${numberFormat.format(rate / 1000.0)}kbps/ ${numberFormat.format(rate / 1000000.0)}Mbps");
    bytecount = 0;
    stopwatch.reset();

    // // ReadWrite
    // QuickBlue.writeValue(widget.deviceId, gssUuid("1337"), gssUuid("3000"), list, BleOutputProperty.withoutResponse);
    // QuickBlue.setValueHandler((deviceId, characteristicId, value) {
    //   log("Value was read.");
    //   if (deviceId == widget.deviceId && characteristicId == gssUuid("2000")) {
    //     if (stopwatch.elapsed < test_duration) {
    //       QuickBlue.readValue(widget.deviceId, gssUuid("1337"), gssUuid("2000"));
    //       bytecount += mtu;
    //     } else {
    //       stopwatch.stop();
    //       var duration = stopwatch.elapsedMilliseconds / 1000.0;
    //       var rate = bytecount / duration;
    //       final numberFormat = NumberFormat("##########.##");
    //       log("Read only throughput: ${numberFormat.format(rate)}bps/ ${numberFormat.format(rate / 1000.0)}kbps/ ${numberFormat.format(rate / 1000000.0)}Mbps");
    //       bytecount = 0;
    //       stopwatch.reset();
    //     }
    //   }
    // });
    // await QuickBlue.readValue(widget.deviceId, gssUuid("1337"), gssUuid("2000"));
    // await Future.delayed(const Duration(seconds: 6));
    // log("All tests should have finished!");
  }
}
