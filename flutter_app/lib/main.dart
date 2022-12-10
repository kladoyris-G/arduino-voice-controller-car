// ignore_for_file: avoid_function_literals_in_foreach_calls

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arduino Voice Control',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
// Στην αρικη οθόνη της εφαρμογης ζητάμε τα απαραίτητα δικαιόματα απο τον χρήστη σε περίπτωση που δεν τα έχει δώσει.
// Αύτα τα δικαίωματα είναι η χρήση του bluetooth, της τοποθεσίας και του μικροφώνου.
// - Το διακαίωμα του bluetooth το ζητάμε για μπορέσει η εφαρμογή να επικοινωνήσει με το arduino.
// - Της τοποθεσίας, το ζητάμε για να μπορεί να το κινητό να χρησιμοποιήσει το Bluetooth low energy, επειδή θέλουμε να επικοινωνήσουμε με συσκευη που είναι BLE.
// - Toυ μικροφώνου το χρειαζόμαστε για να μπορεί η εφαρμογή μας να δέχετε ηχιτικά μηνύματα.
// Αφου αποδεκτούμε όλα τα δικαιώματα, θα μπορούμε να ξεκηνίσουμε να σκανάρουμε για διαθέσιμες Bluetooth συσκευες.

    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return const FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.state}) : super(key: key);

  final BluetoothState? state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              // style: Theme.of(context)
              //     .primaryTextTheme
              //     .subhead
              //     ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ss 1
class FindDevicesScreen extends StatelessWidget {
  const FindDevicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Devices'),
      ),
      body: RefreshIndicator(
        onRefresh: () => FlutterBlue.instance.startScan(timeout: const Duration(seconds: 4)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(const Duration(seconds: 2)).asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: const [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map((d) => ListTile(
                            title: Text(d.name),
                            subtitle: Text(d.id.toString()),
                            trailing: StreamBuilder<BluetoothDeviceState>(
                              stream: d.state,
                              initialData: BluetoothDeviceState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.data == BluetoothDeviceState.connected) {
                                  return ElevatedButton(
                                    child: const Text('OPEN'),
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => DeviceScreen(device: d))),
                                  );
                                }
                                return Text(snapshot.data.toString());
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: const Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: const Icon(Icons.search),
                onPressed: (() async {
                  FlutterBlue flutterBlue = FlutterBlue.instance;
                  // Start scanning
                  flutterBlue.startScan(timeout: const Duration(seconds: 4));

// Listen to scan results
                  var subscription = flutterBlue.scanResults.listen((results) async {
                    // do something with scan results
                    for (ScanResult r in results) {
                      debugPrint('${r.device.name} found! rssi: ${r.rssi}');
                      if (r.device.name == "HMSoft") {
                        await r.device.connect();
                        List<BluetoothService> services = await r.device.discoverServices();
                        services.forEach((service) async {
                          var characteristics = service.characteristics;

                          for (BluetoothCharacteristic c in characteristics) {
                            await c.write([0x12, 0x34]);
                          }
                        });
                      }
                    }
                  });
                  debugPrint(subscription.isPaused.toString());

// Stop scanning
                  flutterBlue.stopScan();
                }));
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

// Αφού συνδεθήκαμε στην επιθημητη συσκεύη, μεταφερόμασται στην κύρια σελίδα της εφαρμογής όπου εδω μπορούμε να δουμε κάποια χαρακτηρηστικα για την συσκεύη
//, καθώς και της δώσουμε της εντολές που επιθυμούμε.

// Η αποστολή της εντολής γίνετια με τον εξής τρόπο:
// Αφού πατήσουμε το κουμπι εγραφής (μικρόφωνο), η εφαρμογή ξεκινάει να ακουει για οποιοδηποτε ηχιτικο ερεθυσμα.
// Μόλις τελείωσουμε φραση που θέλουμε πατάμε πάλι το κουμπι ετσί ώστε να η εφαρμογη να σταματήσει να ακούει και
// να αναγνορήσει την φράση που της δωσαμε.
// Σε περιπτώση που φράση που της δώσαμε είναι κάποια εντολή, τότε θα στείλει ένα σήμα στο μικροεπεξεργαστη με το κωδικό της εντολής
// Για παράδειγμα αν η εκρασή που δώσαμε ήταν το "μπροστα" τότε θα σταλθεί ενα σήμα με τον κωδικό 1.

class _DeviceScreenState extends State<DeviceScreen> {
  final SpeechToText _speechToText = SpeechToText();

  bool _speechEnabled = false;

  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    await Future.delayed(const Duration(seconds: 1));
    debugPrint(_lastWords);
    List<BluetoothService> services = await widget.device.discoverServices();
    services.forEach((service) async {
      // do something with service
      var characteristics = service.characteristics;
      for (BluetoothCharacteristic c in characteristics) {
        switch (_lastWords) {
          case "μπροστά":
            await c.write([1]);

            break;

          case "πίσω":
            await c.write([2]);

            break;
          case "αριστερά":
            await c.write([3]);

            break;
          case "δεξιά":
            await c.write([4]);

            break;
          case "σταμάτα":
            await c.write([5]);

            break;

          default:
            break;
        }
      }
    });
    setState(() {});
  }

  void _onSpeechResult(result) {
    debugPrint(result.recognizedWords);
    debugPrint("==================================");
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  List<int> _getRandomBytes() {
    final math = Random();
    return [math.nextInt(255), math.nextInt(255), math.nextInt(255), math.nextInt(255)];
  }

  List<Widget> _buildServiceTiles(List<BluetoothService> services) {
    return services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map(
                  (c) => CharacteristicTile(
                    characteristic: c,
                    onReadPressed: () => c.read(),
                    onWritePressed: () async {
                      await c.write(_getRandomBytes(), withoutResponse: true);
                      await c.read();
                    },
                    onNotificationPressed: () async {
                      await c.setNotifyValue(!c.isNotifying);
                      await c.read();
                    },
                    descriptorTiles: c.descriptors
                        .map(
                          (d) => DescriptorTile(
                            descriptor: d,
                            onReadPressed: () => d.read(),
                            onWritePressed: () => d.write(_getRandomBytes()),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: widget.device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => widget.device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => widget.device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return FlatButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context).primaryTextTheme.button?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: widget.device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected) ? const Icon(Icons.bluetooth_connected) : const Icon(Icons.bluetooth_disabled),
                title: Text('Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${widget.device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: widget.device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => widget.device.discoverServices(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton(
                onPressed: (() async {
                  List<BluetoothService> services = await widget.device.discoverServices();
                  services.forEach((service) async {
                    var characteristics = service.characteristics;
                    for (BluetoothCharacteristic c in characteristics) {
                      await c.write([4]);
                    }
                  });
                }),
                child: const Text("Right")),
            TextButton(
                onPressed: (() async {
                  List<BluetoothService> services = await widget.device.discoverServices();
                  services.forEach((service) async {
                    var characteristics = service.characteristics;
                    for (BluetoothCharacteristic c in characteristics) {
                      await c.write([3]);
                    }
                  });
                }),
                child: const Text("Left")),
            TextButton(
                onPressed: (() async {
                  List<BluetoothService> services = await widget.device.discoverServices();
                  services.forEach((service) async {
                    var characteristics = service.characteristics;
                    for (BluetoothCharacteristic c in characteristics) {
                      await c.write([1]);
                    }
                  });
                }),
                child: const Text("Forward")),
            TextButton(
                onPressed: (() async {
                  List<BluetoothService> services = await widget.device.discoverServices();
                  services.forEach((service) async {
                    var characteristics = service.characteristics;
                    for (BluetoothCharacteristic c in characteristics) {
                      await c.write([2]);
                    }
                  });
                }),
                child: const Text("Back")),
            TextButton(
                onPressed: (() async {
                  List<BluetoothService> services = await widget.device.discoverServices();
                  services.forEach((service) async {
                    var characteristics = service.characteristics;
                    for (BluetoothCharacteristic c in characteristics) {
                      await c.write([5]);
                    }
                  });
                }),
                child: const Text("Stop")),
            TextButton(
              onPressed:
                  // If not yet listening for speech start, otherwise stop
                  _speechToText.isNotListening ? _startListening : _stopListening,
              // tooltip: 'Listen',
              child: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Last Command: " + _lastWords,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class ScanResultTile extends StatelessWidget {
  const ScanResultTile({Key? key, required this.result, this.onTap}) : super(key: key);

  final ScanResult result;
  final VoidCallback? onTap;

  Widget _buildTitle(BuildContext context) {
    if (result.device.name.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            result.device.name,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            result.device.id.toString(),
            style: Theme.of(context).textTheme.caption,
          )
        ],
      );
    } else {
      return Text(result.device.id.toString());
    }
  }

  Widget _buildAdvRow(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.caption),
          const SizedBox(
            width: 12.0,
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.caption?.apply(color: Colors.black),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String getNiceHexArray(List<int> bytes) {
    return '[${bytes.map((i) => i.toRadixString(16).padLeft(2, '0')).join(', ')}]'.toUpperCase();
  }

  String getNiceManufacturerData(Map<int, List<int>> data) {
    if (data.isEmpty) {
      return 'N/A';
    }
    List<String> res = [];
    data.forEach((id, bytes) {
      res.add('${id.toRadixString(16).toUpperCase()}: ${getNiceHexArray(bytes)}');
    });
    return res.join(', ');
  }

  String getNiceServiceData(Map<String, List<int>> data) {
    if (data.isEmpty) {
      return 'N/A';
    }
    List<String> res = [];
    data.forEach((id, bytes) {
      res.add('${id.toUpperCase()}: ${getNiceHexArray(bytes)}');
    });
    return res.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: _buildTitle(context),
      leading: Text(result.rssi.toString()),
      trailing: RaisedButton(
        child: const Text('CONNECT'),
        color: Colors.black,
        textColor: Colors.white,
        onPressed: (result.advertisementData.connectable) ? onTap : null,
      ),
      children: <Widget>[
        _buildAdvRow(context, 'Complete Local Name', result.advertisementData.localName),
        _buildAdvRow(context, 'Tx Power Level', '${result.advertisementData.txPowerLevel ?? 'N/A'}'),
        _buildAdvRow(context, 'Manufacturer Data', getNiceManufacturerData(result.advertisementData.manufacturerData)),
        _buildAdvRow(context, 'Service UUIDs', (result.advertisementData.serviceUuids.isNotEmpty) ? result.advertisementData.serviceUuids.join(', ').toUpperCase() : 'N/A'),
        _buildAdvRow(context, 'Service Data', getNiceServiceData(result.advertisementData.serviceData)),
      ],
    );
  }
}

class ServiceTile extends StatelessWidget {
  final BluetoothService service;
  final List<CharacteristicTile> characteristicTiles;

  const ServiceTile({Key? key, required this.service, required this.characteristicTiles}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (characteristicTiles.isNotEmpty) {
      return ExpansionTile(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Service'),
            Text(
              '0x${service.uuid.toString().toUpperCase().substring(4, 8)}',
              // style: Theme.of(context).textTheme.body1?.copyWith(
              //     color: Theme.of(context).textTheme.caption?.color)
            )
          ],
        ),
        children: characteristicTiles,
      );
    } else {
      return ListTile(
        title: const Text('Service'),
        subtitle: Text('0x${service.uuid.toString().toUpperCase().substring(4, 8)}'),
      );
    }
  }
}

class CharacteristicTile extends StatelessWidget {
  final BluetoothCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;
  final VoidCallback? onReadPressed;
  final VoidCallback? onWritePressed;
  final VoidCallback? onNotificationPressed;

  const CharacteristicTile({Key? key, required this.characteristic, required this.descriptorTiles, this.onReadPressed, this.onWritePressed, this.onNotificationPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<int>>(
      stream: characteristic.value,
      initialData: characteristic.lastValue,
      builder: (c, snapshot) {
        final value = snapshot.data;
        return ExpansionTile(
          title: ListTile(
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Characteristic'),
                Text(
                  '0x${characteristic.uuid.toString().toUpperCase().substring(4, 8)}',
                  // style: Theme.of(context).textTheme.body1?.copyWith(
                  //     color: Theme.of(context).textTheme.caption?.color)
                )
              ],
            ),
            subtitle: Text(value.toString()),
            contentPadding: const EdgeInsets.all(0.0),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: Icon(
                  Icons.file_download,
                  color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                ),
                onPressed: onReadPressed,
              ),
              IconButton(
                icon: Icon(Icons.file_upload, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                onPressed: onWritePressed,
              ),
              IconButton(
                icon: Icon(characteristic.isNotifying ? Icons.sync_disabled : Icons.sync, color: Theme.of(context).iconTheme.color?.withOpacity(0.5)),
                onPressed: onNotificationPressed,
              )
            ],
          ),
          children: descriptorTiles,
        );
      },
    );
  }
}

class DescriptorTile extends StatelessWidget {
  final BluetoothDescriptor descriptor;
  final VoidCallback? onReadPressed;
  final VoidCallback? onWritePressed;

  const DescriptorTile({Key? key, required this.descriptor, this.onReadPressed, this.onWritePressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Descriptor'),
          Text(
            '0x${descriptor.uuid.toString().toUpperCase().substring(4, 8)}',
            // style: Theme.of(context)
            //     .textTheme
            //     // .body1
            //     ?.copyWith(color: Theme.of(context).textTheme.caption?.color)
          )
        ],
      ),
      subtitle: StreamBuilder<List<int>>(
        stream: descriptor.value,
        initialData: descriptor.lastValue,
        builder: (c, snapshot) => Text(snapshot.data.toString()),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.file_download,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
            ),
            onPressed: onReadPressed,
          ),
          IconButton(
            icon: Icon(
              Icons.file_upload,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
            ),
            onPressed: onWritePressed,
          )
        ],
      ),
    );
  }
}
