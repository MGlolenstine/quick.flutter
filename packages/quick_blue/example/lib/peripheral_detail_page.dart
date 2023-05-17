// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:quick_blue/quick_blue.dart';

String gssUuid(String code) => '0000$code-0000-1000-8000-00805f9b34fb';

final String echoService = gssUuid("1337");

final String send = gssUuid("3000");
final String receive = gssUuid("5000");

const int MTU = 260;

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

enum ConnectionStatus {
  Disconnected,
  Connecting,
  Connected,
}

class _PeripheralDetailPageState extends State<PeripheralDetailPage> {
  ConnectionStatus connected = ConnectionStatus.Disconnected;
  int effectiveMtu = MTU;

  @override
  void initState() {
    super.initState();
    setHandlers();
  }

  @override
  void dispose() {
    super.dispose();
    QuickBlue.disconnect(widget.deviceId);
    QuickBlue.setValueHandler(null);
    QuickBlue.setServiceHandler(null);
    QuickBlue.setConnectionHandler(null);
  }

  Future<void> _handleConnectionChange(
      String deviceId, BlueConnectionState state) async {
    print("Got connection change");
    if (deviceId == widget.deviceId) {
      if (state == BlueConnectionState.connected) {
        connected = ConnectionStatus.Connecting;
      } else {
        connected = ConnectionStatus.Disconnected;
      }
      setState(() {});
      if (connected == ConnectionStatus.Disconnected) {
        EasyLoading.showError("Device disconnected!");
      } else if (connected == ConnectionStatus.Connecting) {
        await Future.delayed(const Duration(milliseconds: 1000));
        QuickBlue.discoverServices(widget.deviceId);
      }
    }
  }

  void _handleServiceResult(
      String deviceId, String service, List<String> characteristics) async {
    print("Received service thingy!");
    if (service != echoService) {
      return;
    }
    // Request 252 MTU
    var mtu = await QuickBlue.requestMtu(
      widget.deviceId,
      MTU,
    );
    effectiveMtu = mtu;

    // Set the notification for data retrival
    var notificationType = BleInputProperty.notification;
    if (connected == ConnectionStatus.Disconnected) {
      notificationType = BleInputProperty.disabled;
    }
    await QuickBlue.setNotifiable(
      widget.deviceId,
      service,
      receive,
      notificationType,
    );
    connected = ConnectionStatus.Connected;
    setState(() {});
  }

  void _handleValueChange(
      String deviceId, String characteristicId, Uint8List value) {
    if (deviceId == widget.deviceId && characteristicId == receive) {
      receivedDataController.text += utf8.decode(value);
      setState(() {});
    }
  }

  TextEditingController sendController = TextEditingController(text: "");
  TextEditingController receivedDataController =
      TextEditingController(text: "");

  Widget _getConnectButton() {
    if (connected == ConnectionStatus.Connected) {
      return ElevatedButton(
        child: const Text('Disconnect'),
        onPressed: () {
          QuickBlue.disconnect(widget.deviceId);
          connected = ConnectionStatus.Disconnected;
          setState(() {});
        },
      );
    } else if (connected == ConnectionStatus.Connecting) {
      return const ElevatedButton(
        child: Text('Connecting'),
        onPressed: null,
      );
    } else {
      return ElevatedButton(
        child: const Text('Connect'),
        onPressed: () {
          QuickBlue.connect(widget.deviceId);
          setState(() {});
        },
      );
    }
  }

  List<Widget> _getSendDataWidgets() {
    return [
      TextField(
        keyboardType: TextInputType.multiline,
        controller: sendController,
        maxLines: null,
        decoration: const InputDecoration(
          labelText: "Send data",
        ),
      ),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          child: const Text('send'),
          onPressed: (connected != ConnectionStatus.Connected)
              ? null
              : () {
                  var value =
                      Uint8List.fromList(utf8.encode(sendController.text));
                  sendController.clear();
                  setState(() {});
                  writeData(value);
                },
        ),
      ),
    ];
  }

  void writeData(Uint8List value) {
    print("Generating packets of size: ${effectiveMtu - 4}");
    var packets = splitToPackets(effectiveMtu - 4, value);
    print("Sending over ${packets.length} packets!");
    for (var p in packets) {
      print("Sending packet of size: ${p.lengthInBytes} bytes");
      QuickBlue.writeValue(
        widget.deviceId,
        echoService,
        send,
        p,
        BleOutputProperty.withoutResponse,
      );
    }
  }

  List<Uint8List> splitToPackets(int length, Uint8List value) {
    if (value.lengthInBytes <= length) {
      return [value];
    }
    var list = value.toList();
    var packets = <Uint8List>[];
    var offset = 0;
    while (offset != list.length) {
      var offsetDelta = min(value.lengthInBytes - offset, length);
      packets
          .add(Uint8List.fromList(list.sublist(offset, offset + offsetDelta)));
      offset += offsetDelta;
    }

    return packets;
  }

  void setHandlers() {
    QuickBlue.setConnectionHandler(_handleConnectionChange);
    QuickBlue.setServiceHandler(_handleServiceResult);
    QuickBlue.setValueHandler(_handleValueChange);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communication test'),
      ),
      body: Column(
        children: [
          Text("Selected device: ${widget.deviceId}"),
          _getConnectButton(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              child: const Text("Clear"),
              onPressed: () => receivedDataController.clear(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: TextField(
                controller: receivedDataController,
                readOnly: true,
              ),
            ),
          ),
          ..._getSendDataWidgets(),
        ],
      ),
    );
  }
}
