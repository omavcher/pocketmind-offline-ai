import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled the sign-in

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }

  // Check if the user has completed the survey
  Future<bool> hasCompletedSurvey(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists && (doc.data()?['surveyCompleted'] == true);
    } catch (e) {
      print("Error checking survey status: $e");
      return false;
    }
  }

  // Save the survey
  Future<void> saveSurvey(String uid, Map<String, dynamic> surveyData) async {
    try {
      surveyData['surveyCompleted'] = true;
      surveyData['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(uid).set(surveyData, SetOptions(merge: true));
    } catch (e) {
      print("Error saving survey: $e");
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
  
  User? get currentUser => _auth.currentUser;
}
