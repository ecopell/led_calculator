import 'dart:io'; // Za provjeru platforme (Windows, Linux, macOS)
import 'package:flutter/cupertino.dart'; // Cupertino widgeti za iOS stil
import 'package:flutter/material.dart'; // Material widgeti za dodatne funkcionalnosti
import 'package:http/http.dart' as http; // Za HTTP zahtjeve
import 'package:bitsdojo_window/bitsdojo_window.dart'; // Za upravljanje prozorima na desktopu
import 'package:url_launcher/url_launcher.dart'; // Za slanje poruka preko WhatsApp i Viber

void main() {
  runApp(MyApp()); // Pokretanje Flutter aplikacije

  // Provjera da li je aplikacija pokrenuta na desktop platformi (Windows, Linux, macOS)
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    doWhenWindowReady(() {
      final win = appWindow;
      const initialSize = Size(800, 720); // Početna veličina prozora (povećano za 20%)
      win.minSize = initialSize; // Postavljanje minimalne veličine prozora
      win.size = initialSize; // Postavljanje početne veličine prozora
      win.alignment = Alignment.center; // Centriranje prozora na ekranu
      win.title = "LED Kalkulator"; // Postavljanje naslova prozora
      win.show(); // Prikaz prozora
    });
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Glavni widget aplikacije koji koristi Cupertino (iOS stil)
    return CupertinoApp(
      debugShowCheckedModeBanner: false, // Skrivanje debug trake
      title: 'LED Kalkulator', // Naslov aplikacije
      home: PriceCalculator(), // Početni ekran aplikacije
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue, // Primarna boja teme
        scaffoldBackgroundColor: CupertinoColors.systemGrey6, // Boja pozadine
      ),
    );
  }
}

class PriceCalculator extends StatefulWidget {
  @override
  _PriceCalculatorState createState() => _PriceCalculatorState(); // Kreiranje stanja za ovaj widget
}

class _PriceCalculatorState extends State<PriceCalculator> {
  final TextEditingController widthController = TextEditingController(); // Kontroler za unos širine
  final TextEditingController heightController = TextEditingController(); // Kontroler za unos visine

  String selectedClient = ""; // Odabrani klijent
  String selectedModule = ""; // Odabrani modul
  List<String> selectedControllers = []; // Lista odabranih kontrolera
  String selectedCurrency = "EUR"; // Odabrana valuta (zadana je EUR)

  List<String> clients = []; // Lista klijenata
  List<String> modules = []; // Lista modula
  List<String> controllers = []; // Lista kontrolera
  List<String> currencies = []; // Lista valuta

  Map<String, Map<String, double>> modulePrices = {}; // Mapa cijena modula po klijentima
  Map<String, Map<String, double>> controllerPrices = {}; // Mapa cijena kontrolera po klijentima
  Map<String, double> currencyRates = {}; // Mapa tečajeva valuta

  String result = ""; // Rezultat izračuna
  int totalModules = 0; // Ukupan broj modula
  int modulesWide = 0; // Broj modula po širini
  int modulesHigh = 0; // Broj modula po visini

  @override
  void initState() {
    super.initState();
    fetchModuleData(); // Dohvaćanje podataka o modulima
    fetchControllerData(); // Dohvaćanje podataka o kontrolerima
    fetchCurrencyData(); // Dohvaćanje podataka o valutama
  }

  // Metoda za dohvaćanje podataka o modulima s Google Sheetsa
  Future<void> fetchModuleData() async {
    final response = await http.get(Uri.parse(
        'https://docs.google.com/spreadsheets/d/175pLrtt8u8gNh-uLgVM8gliRg9KhdM3rjv8wukBj8pQ/gviz/tq?tqx=out:csv&sheet=Moduli'));

    if (response.statusCode == 200) {
      parseCsv(response.body, isModule: true); // Parsiranje CSV podataka ako je zahtjev uspješan
    } else {
      setState(() {
        result = "Greška pri preuzimanju modula."; // Postavljanje poruke o grešci
      });
    }
  }

  // Metoda za dohvaćanje podataka o kontrolerima s Google Sheetsa
  Future<void> fetchControllerData() async {
    final response = await http.get(Uri.parse(
        'https://docs.google.com/spreadsheets/d/175pLrtt8u8gNh-uLgVM8gliRg9KhdM3rjv8wukBj8pQ/gviz/tq?tqx=out:csv&sheet=Kontroleri'));

    if (response.statusCode == 200) {
      parseCsv(response.body, isModule: false); // Parsiranje CSV podataka ako je zahtjev uspješan
    } else {
      setState(() {
        result = "Greška pri preuzimanju kontrolera."; // Postavljanje poruke o grešci
      });
    }
  }

  // Metoda za dohvaćanje podataka o valutama s Google Sheetsa
  Future<void> fetchCurrencyData() async {
    final response = await http.get(Uri.parse(
        'https://docs.google.com/spreadsheets/d/175pLrtt8u8gNh-uLgVM8gliRg9KhdM3rjv8wukBj8pQ/gviz/tq?tqx=out:csv&sheet=Kurs'));

    if (response.statusCode == 200) {
      parseCurrencyCsv(response.body); // Parsiranje CSV podataka ako je zahtjev uspješan
    } else {
      setState(() {
        result = "Greška pri preuzimanju kursa valuta."; // Postavljanje poruke o grešci
      });
    }
  }

  // Metoda za parsiranje CSV podataka za module ili kontrolere
  void parseCsv(String csvData, {required bool isModule}) {
    List<String> lines = csvData.split("\n"); // Dijeljenje CSV podataka po redovima
    if (lines.isEmpty) return;

    List<String> headers = lines[0].split(","); // Dohvaćanje zaglavlja (prvi red)
    List<String> items = headers.sublist(1).map((s) => s.replaceAll('"', '').trim()).toList(); // Čišćenje i formatiranje podataka

    if (isModule) {
      modules = items; // Ako su podaci za module, postavi listu modula
    } else {
      controllers = items; // Ako su podaci za kontrolere, postavi listu kontrolera
    }

    // Iteriranje kroz redove CSV podataka
    for (int i = 1; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;
      List<String> row = line.split(",");
      if (row.length < headers.length) continue;

      String client = row[0].replaceAll('"', '').trim(); // Dohvaćanje imena klijenta
      if (!clients.contains(client)) {
        clients.add(client); // Dodavanje klijenta u listu ako već nije prisutan
      }

      // Odabir mape za spremanje cijena (moduli ili kontroleri)
      Map<String, Map<String, double>> targetMap = isModule ? modulePrices : controllerPrices;
      if (!targetMap.containsKey(client)) {
        targetMap[client] = {}; // Inicijalizacija mape ako klijent nije prisutan
      }

      // Iteriranje kroz cijene za svaki modul/kontroler
      for (int j = 1; j < headers.length; j++) {
        String item = headers[j].replaceAll('"', '').trim(); // Naziv modula/kontrolera
        String valueStr = row[j].replaceAll('"', '').replaceAll(',', '.').trim(); // Cijena
        double price = double.tryParse(valueStr) ?? 0.0; // Pretvorba cijene u broj
        price = double.parse(price.toStringAsFixed(2)); // Zaokruživanje na dvije decimale
        targetMap[client]![item] = price; // Spremanje cijene u mapu
      }
    }

    setState(() {}); // Ponovno iscrtavanje widgeta
  }

  // Metoda za parsiranje CSV podataka za valute
  void parseCurrencyCsv(String csvData) {
    List<String> lines = csvData.split("\n"); // Dijeljenje CSV podataka po redovima
    if (lines.isEmpty) return;

    // Iteriranje kroz redove CSV podataka
    for (int i = 1; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;
      List<String> row = line.split(",");
      if (row.length < 2) continue;

      String currency = row[0].replaceAll('"', '').trim(); // Dohvaćanje valute
      double rate = double.tryParse(row[1].replaceAll('"', '').replaceAll(',', '.').trim()) ?? 1.0; // Dohvaćanje tečaja
      currencyRates[currency] = rate; // Spremanje tečaja u mapu
      if (!currencies.contains(currency)) {
        currencies.add(currency); // Dodavanje valute u listu ako već nije prisutna
      }
    }

    // Dodavanje EUR valute ako nije prisutna u CSV-u
    if (!currencies.contains("EUR")) {
      currencies.add("EUR");
      currencyRates["EUR"] = 1.0; // Postavljanje tečaja za EUR na 1.0
    }

    setState(() {}); // Ponovno iscrtavanje widgeta
  }

  // Metoda za izračun cijene LED ekrana
  void calculatePrice() {
    int width = int.tryParse(widthController.text) ?? 0; // Dohvaćanje širine
    int height = int.tryParse(heightController.text) ?? 0; // Dohvaćanje visine

    // Provjera da li su dimenzije djeljive sa 32 (širina) i 16 (visina)
    if (width % 32 != 0 || height % 16 != 0) {
      setState(() {
        result = "Dimenzije moraju biti deljive sa 32 (širina) i 16 (visina).";
      });
      return;
    }

    // Izračun cijene modula
    double pricePerModule = modulePrices[selectedClient]?[selectedModule] ?? 0.0;
    // Izračun ukupne cijene kontrolera
    double totalControllerPrice = selectedControllers
        .map((controller) => controllerPrices[selectedClient]?[controller] ?? 0.0)
        .reduce((a, b) => a + b);

    // Izračun broja modula po širini i visini
    modulesWide = width ~/ 32;
    modulesHigh = height ~/ 16;
    totalModules = modulesWide * modulesHigh; // Ukupan broj modula

    // Izračun ukupne cijene modula i kontrolera
    double totalModulePrice = totalModules * pricePerModule;
    double totalPrice = totalModulePrice + totalControllerPrice;

    // Pretvorba cijene u odabranu valutu
    double selectedCurrencyRate = currencyRates[selectedCurrency] ?? 1.0;
    double totalPriceInSelectedCurrency = totalPrice * selectedCurrencyRate;

    // Postavljanje rezultata
    setState(() {
      result =
          "Klijent: $selectedClient\n"
          "Modul: $selectedModule\n"
          "Cena jednog modula: €${pricePerModule.toStringAsFixed(2)}\n"
          "Broj modula: ${modulesWide} x ${modulesHigh} = $totalModules\n"
          "Cena svih modula: €${totalModulePrice.toStringAsFixed(2)}\n"
          "Kontroleri: ${selectedControllers.join(', ')}\n"
          "Cena kontrolera: €${totalControllerPrice.toStringAsFixed(2)}\n"
          "Ukupna cena: €${totalPrice.toStringAsFixed(2)}\n"
          "Ukupna cena u $selectedCurrency: ${totalPriceInSelectedCurrency.toStringAsFixed(2)} $selectedCurrency";
    });
  }

  // Metoda za resetiranje polja
  void resetFields() {
    setState(() {
      selectedClient = "";
      selectedModule = "";
      selectedControllers.clear();
      selectedCurrency = "EUR";
      widthController.clear();
      heightController.clear();
      result = "";
      totalModules = 0;
      modulesWide = 0;
      modulesHigh = 0;
    });
  }

  // Metoda za slanje poruke preko WhatsApp-a
  Future<void> sendWhatsAppMessage(String message) async {
    final url = "https://wa.me/?text=${Uri.encodeComponent(message)}"; // Generiranje WhatsApp linka
    if (await canLaunch(url)) {
      await launch(url); // Otvaranje WhatsApp-a
    } else {
      throw "Could not launch $url"; // Greška ako se WhatsApp ne može otvoriti
    }
  }

  // Metoda za slanje poruke preko Viber-a
  Future<void> sendViberMessage(String message) async {
    final url = "viber://forward?text=${Uri.encodeComponent(message)}"; // Generiranje Viber linka
    if (await canLaunch(url)) {
      await launch(url); // Otvaranje Viber-a
    } else {
      throw "Could not launch $url"; // Greška ako se Viber ne može otvoriti
    }
  }

  @override
  Widget build(BuildContext context) {
    double maxWidth = 400; // Maksimalna širina za polja za unos i dugmad

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text("Kalkulator Cene LED Ekrana"), // Naslov trake
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Widget za odabir valute
                      Text("Valuta:", style: TextStyle(fontSize: 16)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Text(
                          selectedCurrency.isEmpty ? "Izaberi valutu" : selectedCurrency,
                          style: TextStyle(fontSize: 18, color: CupertinoColors.activeBlue),
                        ),
                        onPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext context) => CupertinoActionSheet(
                              title: Text("Izaberi valutu"),
                              actions: currencies
                                  .map((currency) => CupertinoActionSheetAction(
                                        child: Text(currency),
                                        onPressed: () {
                                          setState(() {
                                            selectedCurrency = currency;
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

                      // Widget za odabir klijenta
                      Text("Klijent:", style: TextStyle(fontSize: 16)),
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

                      // Widget za odabir modula
                      Text("Modul:", style: TextStyle(fontSize: 16)),
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

                      // Widget za odabir kontrolera
                      Text("Kontroleri:", style: TextStyle(fontSize: 16)),
                      Column(
                        children: selectedControllers.map((controller) {
                          return Row(
                            children: [
                              Expanded(
                                child: CupertinoTextField(
                                  readOnly: true,
                                  placeholder: controller,
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: Icon(CupertinoIcons.delete, color: CupertinoColors.destructiveRed),
                                onPressed: () {
                                  setState(() {
                                    selectedControllers.remove(controller);
                                  });
                                },
                              )
                            ],
                          );
                        }).toList(),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Text(
                          "Dodaj kontroler",
                          style: TextStyle(fontSize: 18, color: CupertinoColors.activeBlue),
                        ),
                        onPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext context) => CupertinoActionSheet(
                              title: Text("Izaberi kontrolere"),
                              actions: controllers
                                  .map((controller) => CupertinoActionSheetAction(
                                        child: Text(controller),
                                        onPressed: () {
                                          setState(() {
                                            if (!selectedControllers.contains(controller)) {
                                              selectedControllers.add(controller);
                                            }
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

                      // Polje za unos širine
                      Container(
                        width: maxWidth,
                        child: CupertinoTextField(
                          controller: widthController,
                          keyboardType: TextInputType.number,
                          placeholder: "Širina u cm",
                          maxLength: 10,
                        ),
                      ),
                      SizedBox(height: 10),

                      // Polje za unos visine
                      Container(
                        width: maxWidth,
                        child: CupertinoTextField(
                          controller: heightController,
                          keyboardType: TextInputType.number,
                          placeholder: "Visina u cm",
                          maxLength: 10,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Gumb za izračun cijene
                      Container(
                        width: maxWidth,
                        child: CupertinoButton(
                          child: Text("Izračunaj cenu", style: TextStyle(color: CupertinoColors.white)),
                          onPressed: calculatePrice,
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Gumb za resetiranje polja
                      Container(
                        width: maxWidth,
                        child: CupertinoButton(
                          child: Text("Resetuj polja", style: TextStyle(color: CupertinoColors.white)),
                          onPressed: resetFields,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Gumb za slanje rezultata na WhatsApp
                      Container(
                        width: maxWidth,
                        child: CupertinoButton(
                          child: Text("Pošalji na WhatsApp", style: TextStyle(color: CupertinoColors.white)),
                          onPressed: () {
                            sendWhatsAppMessage(result); // Slanje rezultata na WhatsApp
                          },
                          color: CupertinoColors.activeGreen,
                        ),
                      ),
                      SizedBox(height: 10),

                      // Gumb za slanje rezultata na Viber
                      Container(
                        width: maxWidth,
                        child: CupertinoButton(
                          child: Text("Pošalji na Viber", style: TextStyle(color: CupertinoColors.white)),
                          onPressed: () {
                            sendViberMessage(result); // Slanje rezultata na Viber
                          },
                          color: CupertinoColors.systemPurple,
                        ),
                      ),
                      SizedBox(height: 20),

                      // Prikaz rezultata
                      Container(
                        padding: EdgeInsets.all(16.0),
                        margin: EdgeInsets.only(top: 20.0),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8.0,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          result,
                          style: TextStyle(fontSize: 18, color: CupertinoColors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: modulesWide > 0 && modulesHigh > 0
                  ? Padding(
                      padding: EdgeInsets.all(16.0),
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: modulesWide, // Broj kolona
                          childAspectRatio: 2 / 1, // Odnos 2:1
                          crossAxisSpacing: 10.0,
                          mainAxisSpacing: 10.0,
                        ),
                        itemCount: totalModules, // Broj modula na osnovu unesenih dimenzija
                        itemBuilder: (context, index) {
                          return Container(
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(fontSize: 16, color: CupertinoColors.black),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        'Unesite dimenzije ekrana i pritisnite "Izračunaj cenu" da biste videli mrežu modula.',
                        style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}