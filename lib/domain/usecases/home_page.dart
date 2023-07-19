// domain/usecases/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ota_package/data/data_helper.dart';



var mtu;
// Functions and classes related to the Domain Layer
class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;
  final FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  final List<BluetoothDevice> devicesList = <BluetoothDevice>[];
  final Map<Guid, List<int>> readValues = <Guid, List<int>>{};

  // Other methods and widgets specific to the UI can be placed here

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  BluetoothDevice? _connectedDevice;
  List<BluetoothService> _services = [];

  _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }
  
  @override
  void initState() {
    super.initState();
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceTolist(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceTolist(result.device);
      }
    });
    widget.flutterBlue.startScan();
  }


 ListView _buildListViewOfDevices() {
  List<Widget> containers = <Widget>[];
  for (BluetoothDevice device in widget.devicesList) {
    if (device.type == BluetoothDeviceType.le) { // Filter out non-connectable devices (LE devices are connectable)
      containers.add(
        SizedBox(
          height: 50,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(device.name == '' ? '(unknown device)' : device.name),
                    Text(device.id.toString()),
                  ],
                ),
              ),
              TextButton(
                child: const Text(
                  'Connect',
                  style: TextStyle(color: Colors.grey),
                ),
                onPressed: () async {
                  widget.flutterBlue.stopScan();
                  try {
                    await device.connect();
                    mtu = await device.mtu.first;
                    print('Current MTU size: $mtu');

                    // Request a new MTU size, e.g., 300
                    int newMtu = 300;
                    await device.requestMtu(newMtu);

                    // The MTU request was successful, print the new MTU size
                    print('New MTU size: $newMtu');
                  } finally {
                    _services = await device.discoverServices();
                  }
                  setState(() {
                    _connectedDevice = device;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }
  }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  List<ButtonTheme> _buildReadWriteNotifyButton(
      BluetoothCharacteristic characteristic) {
    List<ButtonTheme> buttons = <ButtonTheme>[];

    
    if (characteristic.properties.notify) {
      buttons.add(
        ButtonTheme(
          minWidth: 10,
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              child:
                  const Text('NOTIFY', style: TextStyle(color: Colors.grey)),
              onPressed: () async {
                //characteristic.value.listen((value) {
                //  setState(() {
                //    widget.readValues[characteristic.uuid] = value;
                //  });
                //});
                //await characteristic.setNotifyValue(true);
                
                 for (BluetoothService service in _services) {

                  print('this is service-------------------------- ${service.uuid.runtimeType}');
                  //const String guid = Guid('d6f1d96d-594c-4c53-b1c6-144a1dfde6d8');
                  if (service.uuid.toString() == 'd6f1d96d-594c-4c53-b1c6-144a1dfde6d8'){
                    print('lets go ${service.uuid}');
                    // Reads all characteristics
                    var characteristics = service.characteristics;
                    var data_uuid;
                    var control_uuid;
                    for(BluetoothCharacteristic c in characteristics) {
                        //List<int> value = await c.read();
                        //print(value);
                        // Writes to a characteristic

                        //await c.write([0x12, 0x34]);
                        print('my for loop of characteristics-------- ${c.uuid.toString()}');
                        if (c.uuid.toString() == '23408888-1f40-4cd8-9b89-ca8d45f8a5b0'){
                          data_uuid = c;
                        }

                        if (c.uuid.toString() == '7ad671aa-21c0-46a4-b722-270e3ae3d830'){
                          control_uuid = c;
                        }
                    } // end of for loop of characteristics

                    // First step, write packet size data on data uuid
                    // we convert the packet size(int) to 2 bytes little endian
                    //int packetSize = 253;
                    //print('this is what we get as mtu-------------------------------------------- ${mtu}');
                   
                    int packetSize = mtu;
                    Uint8List byteList = Uint8List(2);
                    byteList[0] = packetSize & 0xFF;
                    byteList[1] = (packetSize >> 8) & 0xFF;
                    print(byteList);
                    await data_uuid.write(byteList);

                    // Second step is to write x01 to control_uuid and then check if control_uuid returns value of 0x02
                    await control_uuid.write([1]);

                    List<int> value = await control_uuid.read();
                    print('value returned is this------- ${value[0]}');

                    // third step we check if control_uuid reads 0x02
                    if (value[0] == 2){
                      // fourth step, now we write firmware until complete
                     
           
                      List<Uint8List> binaryChunks = await readBinaryFile('assets/esp32_ble_ota.bin');
                      print('this is length of binary chunks ----- ${binaryChunks.length}');
                      int packageNumber = 0;
                      for (Uint8List chunk in binaryChunks) {
                        // Process each chunk of binary data (253 bytes)
                        // ...
                        //print('this is the first chunk thank you ${chunk[0]}');
                        //break;

                        //final intList = uint8ListToIntList(chunk);
                        print('${chunk.length}');

                        await data_uuid.write(chunk);
                        print(chunk);
                        packageNumber++;
                        print('writing package number ${packageNumber} of ${binaryChunks.length} to esp32');
                        
                      }
                    }
                    print('-----------------------  SECOND LAST thing');
                    await control_uuid.write([4]);

                    print('-------------------------------------- THE LAST THING');
                    value = await control_uuid.read();
                    if (value[0] == 5){
                      print('OTA update finished');
                    }

                }
              }}, // end of async
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  ListView _buildConnectDeviceView() {
    List<Widget> containers = <Widget>[];

    for (BluetoothService service in _services) {
      List<Widget> characteristicsWidget = <Widget>[];

      //print('this is service-------------------------- ${service.uuid.runtimeType}');
      //const String guid = Guid('d6f1d96d-594c-4c53-b1c6-144a1dfde6d8');
      //if (service.uuid.toString() == 'd6f1d96d-594c-4c53-b1c6-144a1dfde6d8'){
        //print('lets go ${service.uuid}');
        // Reads all characteristics
        //var characteristics = service.characteristics;
        //for(BluetoothCharacteristic c in characteristics) {
         //   List<int> value = await c.read();
         //   print(value);
        //}

        // Writes to a characteristic
        //await c.write([0x12, 0x34])
      //}

      for (BluetoothCharacteristic characteristic in service.characteristics) {
        characteristicsWidget.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(characteristic.uuid.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: <Widget>[
                    ..._buildReadWriteNotifyButton(characteristic),
                  ],
                ),
                Row(
                  children: <Widget>[
                    Text('Value: ${widget.readValues[characteristic.uuid]}'),
                  ],
                ),
                const Divider(),
              ],
            ),
          ),
        );
      }
      containers.add(
        ExpansionTile(
            title: Text(service.uuid.toString()),
            children: characteristicsWidget),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }


  ListView _buildView() {
    if (_connectedDevice != null) {
      return _buildConnectDeviceView();
    }
    return _buildListViewOfDevices();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: _buildView(),
      );
}