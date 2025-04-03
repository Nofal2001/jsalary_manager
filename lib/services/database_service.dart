import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_config.dart'; // Add this import

class DatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: firebaseConfig['apiKey']!,
        appId: firebaseConfig['appId']!,
        messagingSenderId: firebaseConfig['messagingSenderId']!,
        projectId: firebaseConfig['projectId']!,
        authDomain: firebaseConfig['authDomain']!,
        storageBucket: firebaseConfig['storageBucket']!,
      ),
    );

    // await _firestore.enablePersistence(); // ❌ Not supported on Windows
  }
}
