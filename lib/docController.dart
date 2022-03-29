import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DetailsController {
  uploadDetails(
    String date,
    String note,
    String fileUrl,
  ) async {
    List<String> splitDate = date.split(' ');
    List<String> dateList = [];
    for (int i = 0; i < splitDate.length; i++) {
      for (int j = 0; j < splitDate[i].length; j++) {
        dateList.add(splitDate[i].substring(0, j).toLowerCase());
      }
    }
    List<String> splitNote = note.split(' ');
    List<String> noteList = [];
    for (int i = 0; i < splitNote.length; i++) {
      for (int j = 0; j < splitNote[i].length; j++) {
        noteList.add(splitNote[i].substring(0, j).toLowerCase());
      }
    }

    await FirebaseFirestore.instance.collection('details').doc().set({
      'date': date,
      'dateList': dateList,
      'note': note,
      'noteList': noteList,
      'fileUrl': fileUrl,
    });
  }

  //delete details
  deleteDoc(String id) async {
    await FirebaseFirestore.instance.collection('details').doc(id).delete();
  }

  //delete file
  deleteFile(fileUrl) async {
    await FirebaseStorage.instance.refFromURL(fileUrl).delete();
  }

}
