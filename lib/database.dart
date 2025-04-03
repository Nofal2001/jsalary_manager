import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCjHGF4wAzeVHO7qvRlhR32n1hL4MCKbVk",
        appId: "1:1012613568722:web:203376804dc5e38c4b350b",
        messagingSenderId: "1012613568722",
        projectId: "salary-app-a6888",
        authDomain: "salary-app-a6888.firebaseapp.com",
        databaseURL: "https://salary-app-a6888-default-rtdb.firebaseio.com",
        storageBucket: "salary-app-a6888.appspot.com", // Corrected this line
      ),
    );
  }

  static Future<void> addWorker(Map<String, dynamic> workerData) async {
    await _firestore.collection('workers').add(workerData);
  }
}
