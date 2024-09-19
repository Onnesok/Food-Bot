import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';


class Maintablepage extends StatefulWidget {
  final BluetoothDevice server;

  const Maintablepage({super.key, required this.server});

  @override
  State<Maintablepage> createState() => _MaintablepageState();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _MaintablepageState extends State<Maintablepage> {
  List<String> dataList = [];

  static final clientID = 0;
  BluetoothConnection? connection;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;

  bool get isConnected => (connection?.isConnected ?? false);

  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();
    _loadData();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        messages.add(
          _Message(
            1,
            backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index),
          ),
        );
        _messageBuffer = dataString.substring(index);
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    textEditingController.clear();

    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        await connection!.output.allSent;

        setState(() {
          messages.add(_Message(clientID, text));
        });

        Future.delayed(Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(
              listScrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 333),
              curve: Curves.easeOut);
        });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }

  // Load data from SharedPreferences
  void _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      dataList = prefs.getStringList('dataList') ?? [];
    });
  }

  // Save data to SharedPreferences
  void _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('dataList', dataList); // Save current dataList
  }

  // Delete a specific item from the list and save the updated list
  void _deleteData(int index) {
    setState(() {
      Fluttertoast.showToast(msg: "Deleted: ${dataList[index]}");
      dataList.removeAt(index); // Remove the selected item
      _saveData(); // Save the updated list
    });
  }

  void dialogueInput(BuildContext context) {
    TextEditingController inputController1 = TextEditingController();
    TextEditingController inputController2 = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Center(
            child: Text(
              "Add Table Data",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.green,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First Input Field
              TextField(
                controller: inputController1,
                decoration: InputDecoration(
                  labelText: "Enter Table No",
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: "e.g. 1",
                  hintStyle: TextStyle(
                      fontStyle: FontStyle.normal,
                      color: Colors.grey.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  // Restricts input to digits only
                ],
              ),
              SizedBox(height: 10),
              // Second Input Field
              TextField(
                controller: inputController2,
                decoration: InputDecoration(
                  labelText: "Stop position",
                  labelStyle: TextStyle(color: Colors.grey),
                  hintText: "e.g. Right",
                  hintStyle: TextStyle(
                      fontStyle: FontStyle.normal,
                      color: Colors.grey.withOpacity(0.6)),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            // Cancel Button
            TextButton(
              child: Text(
                "Cancel",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Save",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                String inputData1 = inputController1.text;
                String inputData2 = inputController2.text;

                if (inputData1.isNotEmpty && inputData2.isNotEmpty) {
                  setState(() {
                    dataList.add(
                        "$inputData1: $inputData2"); // Combine the two inputs
                    _saveData(); // Save data when new entry is added
                  });
                  Fluttertoast.showToast(msg: "Data saved: $inputData1");
                } else {
                  Fluttertoast.showToast(msg: "Please fill in both fields");
                }

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Row> list = messages.map((_message) {
      return Row(
        children: <Widget>[
          Container(
            child: Text(
                (text) {
                  return text == '/shrug' ? '¯\\_(ツ)_/¯' : text;
                }(_message.text.trim()),
                style: TextStyle(color: Colors.white)),
            padding: EdgeInsets.all(12.0),
            margin: EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
            width: 222.0,
            decoration: BoxDecoration(
                color:
                    _message.whom == clientID ? Colors.blueAccent : Colors.grey,
                borderRadius: BorderRadius.circular(7.0)),
          ),
        ],
        mainAxisAlignment: _message.whom == clientID
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
      );
    }).toList();

    final serverName = widget.server.name ?? "Unknown";

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Main Table Setup',
          style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.black87.withOpacity(0.7),
            height: MediaQuery.of(context).size.height * 0.4,
            width: MediaQuery.of(context).size.width,
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.terminal, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Terminal',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isConnecting
                      ? Center(
                          child: Text("Connecting please wait", style: TextStyle(color: Colors.white, fontSize: 20, fontStyle: FontStyle.italic),),
                        )
                      : isConnected
                          ? Container(
                              width: MediaQuery.of(context).size.width,
                              color: Colors.black38,
                              child: ListView(
                                padding: const EdgeInsets.all(12.0),
                                controller: listScrollController,
                                children: list,
                              ),
                              //Center(child: Text("Data will be shown here", style: TextStyle(color: Colors.white),)),
                            )
                          : Center(
                              child: Text("Disconnected", style: TextStyle(color: Colors.white, fontSize: 20, fontStyle: FontStyle.italic),),
                            ),
                ),
              ],
            ),
          ),
          // Display the list of saved data below the container
          Expanded(
            child: ListView.builder(
              itemCount: dataList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  onTap: () {
                    String tableNumber = dataList[index]
                        .split(':')[0]; // Extract the table number (before ':')
                    _sendMessage(tableNumber); // Send the table number
                    Fluttertoast.showToast(
                        msg: "Sent table number: $tableNumber");
                  },
                  title: Text(dataList[index]),
                  leading: Icon(Icons.data_array),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline_outlined,
                        color: Colors.red, size: 26),
                    onPressed: () {
                      _deleteData(
                          index); // Call delete function when icon is tapped
                    },
                  ),
                );
              },
            ),
          ),
          ListTile(
            title: Text(""), // empty list for delte button safety
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          dialogueInput(context);
        },
        child: Icon(Icons.table_bar_sharp, color: Colors.white),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
