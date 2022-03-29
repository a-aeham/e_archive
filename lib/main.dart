import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:readmore/readmore.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'docController.dart';

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'AE'),
      ],
      debugShowCheckedModeBanner: false,
      home: const Home(),
      routes: {
        '/notes': (context) => const SearchByNote(),
        '/date': (context) => const SearchByDate(),
      },
    ),
  );
}

// Recent Screen **************************************************************

class Home extends StatefulWidget {
  final url;
  const Home({Key? key, this.url}) : super(key: key);
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  var selectedItem = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'المضافة حديثا',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'noto',
            fontSize: 18,
          ),
        ),
        actions: <Widget>[
          PopupMenuButton(
            icon: const Icon(
              Icons.more_vert,
              color: Color(0xFF2354A6),
            ),
            onSelected: ((value) {
              setState(() {
                selectedItem = value.toString();
              });
              Navigator.pushNamed(context, '/$selectedItem');
              print(value);
            }),
            itemBuilder: (BuildContext bc) {
              return [
                const PopupMenuItem(
                  child: Text(
                    'البحث حسب الموضوع',
                    style: TextStyle(
                      fontFamily: 'noto',
                      color: Color(0xFF2354A6),
                    ),
                  ),
                  value: 'notes',
                ),
                const PopupMenuItem(
                  child: Text(
                    'البحث حسب التاريخ',
                    style: TextStyle(
                      fontFamily: 'noto',
                      color: Color(0xFF2354A6),
                    ),
                  ),
                  value: 'date',
                ),
              ];
            },
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2354A6),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddDocument(),
            ),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection("details")
              .limit(10)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasData) {
              return ListView(
                children: snapshot.data!.docs.map((DocumentSnapshot document) {
                  return GestureDetector(
                    onLongPress: () async {
                      await FirebaseStorage.instance
                          .refFromURL(document['fileUrl'])
                          .delete();
                      DetailsController().deleteDoc(document.id);
                    },
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => View(
                            url: document['fileUrl'],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF2354A6),
                            blurRadius: 0,
                            offset: Offset(-5, 5),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            width: 2,
                            style: BorderStyle.solid,
                            color: Colors.black,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ReadMoreText(
                              document['note'],
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'Noto',
                              ),
                              trimLines: 2,
                              colorClickableText: const Color(0xFF2354A6),
                              trimMode: TrimMode.Line,
                              trimCollapsedText: 'المزيد',
                              moreStyle: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'Noto',
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text(
                              document['date'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'noto',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'images/No_data.png',
                    color: Colors.white.withOpacity(0.5),
                    colorBlendMode: BlendMode.modulate,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  const Text(
                    'No Data',
                    style: TextStyle(fontSize: 20, fontFamily: 'josefin'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Add File Screen *************************************************************

class AddDocument extends StatefulWidget {
  const AddDocument({Key? key}) : super(key: key);

  @override
  State<AddDocument> createState() => _AddDocumentState();
}

class _AddDocumentState extends State<AddDocument> {
  DateTime date = DateTime.now();
  final formKey = GlobalKey<FormState>();
  final _docNotesController = TextEditingController();
  bool isLoading = false;
  UploadTask? task;
  String fileUrl = "";
  File? file;

  Future selectFile() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(allowMultiple: false);
    var path = result!.files.single.path.toString();
    setState(() {
      file = File(path);
    });
    print('**********************************');
    print('File : $file');
  }

  Future uploadFile() async {
    String name = DateTime.now().millisecondsSinceEpoch.toString();
    var pdfFile = FirebaseStorage.instance.ref().child('/$name.pdf');
    UploadTask task = pdfFile.putData(file!.readAsBytesSync());
    TaskSnapshot snapshot = await task;
    fileUrl = await snapshot.ref.getDownloadURL();
    DetailsController().uploadDetails('${date.day}/${date.month}/${date.year}',
        _docNotesController.text, fileUrl);
    print('**********************************');
    print(fileUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text(
          'إضافة مستند',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'noto',
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2354A6),
        child: const Icon(Icons.cloud_upload_outlined),
        onPressed: () {
          if (file != null) {
            if (formKey.currentState!.validate()) {
              uploadFile();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => Home(
                    url: fileUrl,
                  ),
                ),
              );
              print('Uploaded ! ************************');
            }
          } else {
            selectFile();
          }
        },
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Form(
                key: formKey,
                child: Column(
                  children: [
                    SizedBox(
                      height: 50,
                      width: 175,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          primary: const Color(0xFF2354A6),
                          onPrimary: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            isLoading = true;
                          });
                          selectFile();
                          Future.delayed(const Duration(seconds: 3), () {
                            setState(() {
                              isLoading = false;
                            });
                          });
                        },
                        icon: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Icon(Icons.attach_file),
                        label: const Text(
                          "إضافة مستند",
                          style: TextStyle(fontFamily: 'noto'),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      child: TextFormField(
                        style: const TextStyle(
                          fontFamily: 'noto',
                          fontSize: 16,
                        ),
                        validator: ((value) {
                          if (value!.isEmpty) {
                            return 'الرجاء إدخال الملاحظات';
                          }
                          return null;
                        }),
                        controller: _docNotesController,
                        keyboardType: TextInputType.multiline,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          errorStyle: TextStyle(
                            fontFamily: 'noto',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.black, width: 3),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.black, width: 3),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                      //add container Decoration
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF2354A6),
                            blurRadius: 0,
                            offset: Offset(-5, 5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 50,
                          width: 55,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                primary: const Color(0xFF2354A6),
                                onPrimary: Colors.white,
                              ),
                              onPressed: () async {
                                DateTime? newDate = await showDatePicker(
                                  context: context,
                                  initialDate: date,
                                  firstDate: DateTime(2014),
                                  lastDate: DateTime(2030),
                                );
                                if (newDate == null) {
                                  return;
                                }
                                setState(() {
                                  date = newDate;
                                });
                              },
                              child: const Icon(Icons.calendar_today)),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        SizedBox(
                          height: 50,
                          width: 110,
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: const BoxDecoration(boxShadow: [
                              BoxShadow(
                                color: Color(0xFF2354A6),
                                // spreadRadius: 1,
                                blurRadius: 0,
                                offset: Offset(-5, 7),
                              ),
                            ]),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                    width: 2,
                                    style: BorderStyle.solid,
                                    color: Colors.black),
                              ),
                              // color: Colors.amber,
                              child: Text(
                                '${date.day}/${date.month}/${date.year}',
                                style: const TextStyle(
                                  fontFamily: 'josefin',
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // const SizedBox(
                        //   width: 10,
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// View Screen *****************************************************************

class View extends StatefulWidget {
  final url;
  const View({Key? key, this.url}) : super(key: key);

  @override
  State<View> createState() => _ViewState();
}

class _ViewState extends State<View> {
  PdfViewerController? _pdfViewerController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'عرض المستند',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'noto',
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SfPdfViewer.network(
        widget.url,
        controller: _pdfViewerController,
      ),
    );
  }
}

// Search by Date *********************************************************

class SearchByDate extends StatefulWidget {
  const SearchByDate({Key? key}) : super(key: key);

  @override
  State<SearchByDate> createState() => _SearchByDateState();
}

class _SearchByDateState extends State<SearchByDate> {
  final searchController = TextEditingController();
  String? searchText;
  final database = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                child: TextFormField(
                  keyboardType: TextInputType.datetime,
                  style: const TextStyle(
                    fontFamily: 'noto',
                  ),
                  onChanged: (value) {
                    setState(() {
                      setState(() {
                        searchText = value;
                      });
                    });
                  },
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث بواسطة التاريخ',
                    hintStyle: const TextStyle(
                      fontFamily: 'noto',
                      color: Colors.blueGrey,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        if (searchController.text.isEmpty) {
                          Navigator.pop(context);
                        } else {
                          searchController.clear();
                        }
                      },
                      icon: const Icon(Icons.clear),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
                //add container Decoration
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF2354A6),
                      blurRadius: 1,
                      offset: Offset(-5, 5),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: (searchText == null || searchText?.trim() == '')
                      ? database.collection('details').snapshots()
                      : database
                          .collection('details')
                          .where('dateList', arrayContains: searchText)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    switch (snapshot.connectionState) {
                      case ConnectionState.waiting:
                        return const Center(child: Text('Loading...'));
                      default:
                        return ListView(
                          children: snapshot.data!.docs
                              .map((DocumentSnapshot document) {
                            return GestureDetector(
                              onLongPress: () async {
                                await FirebaseStorage.instance
                                    .refFromURL(document['fileUrl'])
                                    .delete();
                                DetailsController().deleteDoc(document.id);
                              },
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => View(
                                      url: document['fileUrl'],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: const BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF2354A6),
                                      blurRadius: 0,
                                      offset: Offset(-5, 5),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      width: 2,
                                      style: BorderStyle.solid,
                                      color: Colors.black,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        document['date'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'noto',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      ReadMoreText(
                                        document['note'],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontFamily: 'Noto',
                                        ),
                                        trimLines: 2,
                                        colorClickableText:
                                            const Color(0xFF2354A6),
                                        trimMode: TrimMode.Line,
                                        trimCollapsedText: 'المزيد',
                                        moreStyle: const TextStyle(
                                          fontSize: 15,
                                          fontFamily: 'Noto',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Search by Note *********************************************************

class SearchByNote extends StatefulWidget {
  const SearchByNote({Key? key}) : super(key: key);

  @override
  State<SearchByNote> createState() => _SearchByNoteState();
}

class _SearchByNoteState extends State<SearchByNote> {
  final searchController = TextEditingController();
  String? searchText;
  final database = FirebaseFirestore.instance;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                child: TextFormField(
                  style: const TextStyle(
                    fontFamily: 'noto',
                  ),
                  onChanged: (value) {
                    setState(() {
                      setState(() {
                        searchText = value;
                      });
                    });
                  },
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث بواسطة الملاحظات',
                    hintStyle: const TextStyle(
                      fontFamily: 'noto',
                      color: Colors.blueGrey,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        if (searchController.text.isEmpty) {
                          Navigator.pop(context);
                        } else {
                          searchController.clear();
                        }
                      },
                      icon: const Icon(Icons.clear),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
                //add container Decoration
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF2354A6),
                      blurRadius: 1,
                      offset: Offset(-5, 5),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: (searchText == null || searchText?.trim() == '')
                      ? database.collection('details').snapshots()
                      : database
                          .collection('details')
                          .where('noteList', arrayContains: searchText)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    switch (snapshot.connectionState) {
                      case ConnectionState.waiting:
                        return const Text('Loading...');
                      default:
                        return ListView(
                          children: snapshot.data!.docs
                              .map((DocumentSnapshot document) {
                            return GestureDetector(
                              onLongPress: () async {
                                await FirebaseStorage.instance
                                    .refFromURL(document['fileUrl'])
                                    .delete();
                                DetailsController().deleteDoc(document.id);
                              },
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => View(
                                      url: document['fileUrl'],
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: const BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF2354A6),
                                      blurRadius: 0,
                                      offset: Offset(-5, 5),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      width: 2,
                                      style: BorderStyle.solid,
                                      color: Colors.black,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ReadMoreText(
                                        document['note'],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontFamily: 'Noto',
                                        ),
                                        trimLines: 2,
                                        colorClickableText:
                                            const Color(0xFF2354A6),
                                        trimMode: TrimMode.Line,
                                        trimCollapsedText: 'المزيد',
                                        moreStyle: const TextStyle(
                                          fontSize: 15,
                                          fontFamily: 'Noto',
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 10,
                                      ),
                                      Text(
                                        document['date'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'noto',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

