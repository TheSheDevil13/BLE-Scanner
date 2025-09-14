import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const BLEScannerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BLEScannerScreen extends StatefulWidget {
  const BLEScannerScreen({super.key});

  @override
  State<BLEScannerScreen> createState() => _BLEScannerScreenState();
}

class _BLEScannerScreenState extends State<BLEScannerScreen> {
  bool isScanning = false;
  List<ScanResult> scanResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scanner'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (isScanning) {
                      stopScan();
                    } else {
                      startScan();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isScanning ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isScanning ? 'Stop Scan' : 'Start Scan'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      scanResults.clear();
                    });
                  },
                  child: const Text('Clear Results'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Found ${scanResults.length} devices',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: scanResults.isEmpty
                ? const Center(
                    child: Text(
                      'No devices found.\nMake sure Bluetooth is on and start scanning.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: scanResults.length,
                    itemBuilder: (context, index) {
                      final result = scanResults[index];
                      final device = result.device;
                      final advertisementData = result.advertisementData;
                      
                      // Get device name from multiple sources
                      String deviceName = device.platformName.isNotEmpty 
                          ? device.platformName 
                          : advertisementData.localName.isNotEmpty
                              ? advertisementData.localName
                              : 'Unknown Device';
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0, 
                          vertical: 4.0
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.bluetooth,
                            color: result.rssi > -60 ? Colors.green : 
                                   result.rssi > -80 ? Colors.orange : Colors.red,
                          ),
                          title: Text(
                            deviceName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('MAC: ${device.remoteId}'),
                              Text('RSSI: ${result.rssi} dBm'),
                              if (advertisementData.serviceUuids.isNotEmpty)
                                Text('Services: ${advertisementData.serviceUuids.map((uuid) {
                                  String uuidStr = uuid.toString();
                                  return uuidStr.length > 8 ? uuidStr.substring(0, 8) : uuidStr;
                                }).join(', ')}'),
                              if (advertisementData.manufacturerData.isNotEmpty)
                                Text('Manufacturer: ${advertisementData.manufacturerData.keys.first}'),
                            ],
                          ),
                          trailing: Text(
                            result.rssi > -60 ? 'Strong' : 
                            result.rssi > -80 ? 'Medium' : 'Weak',
                            style: TextStyle(
                              color: result.rssi > -60 ? Colors.green : 
                                     result.rssi > -80 ? Colors.orange : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void startScan() async {
    debugPrint('Starting BLE scan...');
    
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('Bluetooth not supported');
        _showSnackBar('Bluetooth not supported on this device');
        return;
      }

      // Check if Bluetooth is turned on
      var state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        debugPrint('Bluetooth is not turned on');
        _showSnackBar('Please turn on Bluetooth to scan for devices');
        return;
      }

      // Clear previous results
      setState(() {
        isScanning = true;
        scanResults.clear();
      });

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30), // Scan for 30 seconds
        androidUsesFineLocation: true,
      );

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          // Remove duplicates based on device MAC address
          for (ScanResult result in results) {
            // Remove existing entry for this device if present
            scanResults.removeWhere((existing) => 
                existing.device.remoteId == result.device.remoteId);
            // Add the new result
            scanResults.add(result);
          }
          // Sort by signal strength (RSSI)
          scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
        });

        // Still print to console for debugging
        for (ScanResult result in results) {
          debugPrint('\n--- Device Found ---');
          debugPrint('Name: ${result.device.platformName}');
          debugPrint('Local Name: ${result.advertisementData.localName}');
          debugPrint('MAC Address: ${result.device.remoteId}');
          debugPrint('RSSI: ${result.rssi}');
          debugPrint('Service UUIDs: ${result.advertisementData.serviceUuids}');
          debugPrint('Manufacturer Data: ${result.advertisementData.manufacturerData}');
          debugPrint('Service Data: ${result.advertisementData.serviceData}');
          debugPrint('------------------\n');
        }
      }, onDone: () {
        setState(() {
          isScanning = false;
        });
        debugPrint('Scan complete');
        _showSnackBar('Scan completed. Found ${scanResults.length} devices.');
      }, onError: (error) {
        debugPrint('Scan error: $error');
        setState(() {
          isScanning = false;
        });
        _showSnackBar('Scan error: $error');
      });

    } catch (e) {
      debugPrint('Error during scan: $e');
      setState(() {
        isScanning = false;
      });
      _showSnackBar('Error during scan: $e');
    }
  }

  void stopScan() async {
    debugPrint('Stopping BLE scan...');
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
    setState(() {
      isScanning = false;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    stopScan();
    super.dispose();
  }
}