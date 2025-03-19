import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:bitsdojo_window/bitsdojo_window.dart';

void main() {
  runApp(MyApp());
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    doWhenWindowReady(() {
      final win = appWindow;
      const initialSize = Size(400, 600);
      win.minSize = initialSize;
      win.size = initialSize;
      win.alignment = Alignment.center;
      win.title = "LED Kalkulator";
      win.show();
    });
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'LED Kalkulator',
      home: PriceCalculator(),
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        // Postavljamo pozadinsku boju koja nije bela
        scaffoldBackgroundColor: CupertinoColors.systemGrey6,
      ),
    );
  }
}

class PriceCalculator extends StatefulWidget {
  @override
  _PriceCalculatorState createState() => _PriceCalculatorState();
}

class _PriceCalculatorState extends State<PriceCalculator> {
  final TextEditingController widthController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  String selectedClient = "";
  String selectedModule = "";
  List<String> clients = [];
  List<String> modules = [];
  Map<String, Map<String, double>> pricingData = {};
  String result = ""; // Deklaracija varijable

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    // Zamenite YOUR_SPREADSHEET_ID stvarnim ID-jem vaše Google Sheets tabele
    final response = await http.get(Uri.parse(
        'https://docs.google.com/spreadsheets/d/175pLrtt8u8gNh-uLgVM8gliRg9KhdM3rjv8wukBj8pQ/gviz/tq?tqx=out:csv'));
    if (response.statusCode == 200) {
      parseCsv(response.body);
    } else {
      setState(() {
        result = "Error fetching data";
      });
    }
  }

  void parseCsv(String csvData) {
    List<String> lines = csvData.split("\n");
    if (lines.isEmpty) return;

    // Prvi red su zaglavlja: prvi element je "Klijent", ostali su nazivi modula.
    List<String> headers = lines[0].split(",");
    modules = headers.sublist(1).map((s) => s.replaceAll('"', '').trim()).toList();

    for (int i = 1; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;
      List<String> row = line.split(",");
      if (row.length < headers.length) continue;

      String client = row[0].replaceAll('"', '').trim();
      if (!clients.contains(client)) {
        clients.add(client);
      }
      pricingData[client] = {};
      for (int j = 1; j < headers.length; j++) {
        String module = headers[j].replaceAll('"', '').trim();
        String valueStr = row[j]
            .replaceAll('"', '')
            .replaceAll(',', '.')
            .trim();
        double price = double.tryParse(valueStr) ?? 0.0;
        pricingData[client]![module] = price;
      }
    }
    setState(() {});
  }

  void calculatePrice() {
    int width = int.tryParse(widthController.text) ?? 0;
    int height = int.tryParse(heightController.text) ?? 0;

    if (width % 32 != 0 || height % 16 != 0) {
      setState(() {
        result = "Dimenzije moraju biti deljive sa 32 (širina) i 16 (visina).";
      });
      return;
    }

    int modulesWide = width ~/ 32;
    int modulesHigh = height ~/ 16;
    int totalModules = modulesWide * modulesHigh;
    double pricePerModule = pricingData[selectedClient]?[selectedModule] ?? 0.0;
    double totalPrice = totalModules * pricePerModule;

    setState(() {
      result =
          "Klijent: $selectedClient\nModul: $selectedModule\nCena jednog modula: €${pricePerModule.toStringAsFixed(2)}\nBroj modula: ${modulesWide} x ${modulesHigh} = $totalModules\nUkupna cena: €${totalPrice.toStringAsFixed(2)}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGrey6,
      navigationBar: CupertinoNavigationBar(
        middle: Text("Kalkulator Cene LED Ekrana"),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Klijent:", style: TextStyle(fontSize: 16, color: CupertinoColors.black)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      selectedClient.isEmpty ? "Izaberi klijenta" : selectedClient,
                      style: TextStyle(fontSize: 18, color: CupertinoColors.activeBlue),
                    ),
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) => CupertinoActionSheet(
                          title: Text("Izaberi klijenta"),
                          actions: clients
                              .map((client) => CupertinoActionSheetAction(
                                    child: Text(client),
                                    onPressed: () {
                                      setState(() {
                                        selectedClient = client;
                                      });
                                      Navigator.pop(context);
                                    },
                                  ))
                              .toList(),
                          cancelButton: CupertinoActionSheetAction(
                            child: Text("Otkaži"),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 10),
                  Text("Modul:", style: TextStyle(fontSize: 16, color: CupertinoColors.black)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      selectedModule.isEmpty ? "Izaberi modul" : selectedModule,
                      style: TextStyle(fontSize: 18, color: CupertinoColors.activeBlue),
                    ),
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) => CupertinoActionSheet(
                          title: Text("Izaberi modul"),
                          actions: modules
                              .map((module) => CupertinoActionSheetAction(
                                    child: Text(module),
                                    onPressed: () {
                                      setState(() {
                                        selectedModule = module;
                                      });
                                      Navigator.pop(context);
                                    },
                                  ))
                              .toList(),
                          cancelButton: CupertinoActionSheetAction(
                            child: Text("Otkaži"),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 10),
                  CupertinoTextField(
                    controller: widthController,
                    keyboardType: TextInputType.number,
                    placeholder: "Širina u cm",
                    placeholderStyle: TextStyle(color: CupertinoColors.systemGrey),
                  ),
                  SizedBox(height: 10),
                  CupertinoTextField(
                    controller: heightController,
                    keyboardType: TextInputType.number,
                    placeholder: "Visina u cm",
                    placeholderStyle: TextStyle(color: CupertinoColors.systemGrey),
                  ),
                  SizedBox(height: 20),
                  CupertinoButton.filled(
                    child: Text("Izračunaj cenu"),
                    onPressed: calculatePrice,
                  ),
                  SizedBox(height: 20),
                  Text(
                    result,
                    style: TextStyle(fontSize: 18, color: CupertinoColors.black),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
