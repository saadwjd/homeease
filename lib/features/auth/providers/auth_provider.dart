import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import '../models/user_model.dart';
import '../models/provider_model.dart';

// ─── Firebase instances ────────────────────────────────────────────────────

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ─── Auth state stream ─────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// ─── Current user data from Firestore ─────────────────────────────────────

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final firestore = ref.watch(firestoreProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ─── Auth Notifier ─────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthNotifier(this._auth, this._firestore) : super(const AsyncValue.data(null));

  // ── Email Sign Up ────────────────────────────────────────────────────────
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required UserRole role,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      await _saveNewUser(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        role: role,
      );
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e, st) {
      state = AsyncValue.error(_authErrorMessage(e.code), st);
    }
  }

  // ── Email Sign In ────────────────────────────────────────────────────────
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e, st) {
      state = AsyncValue.error(_authErrorMessage(e.code), st);
    }
  }

  // ── Google Sign In ───────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final googleSignIn = gsi.GoogleSignIn();
      // Sign out first to force account picker every time
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      await _createUserIfNotExists(
        uid: user.uid,
        name: user.displayName ?? 'User',
        email: user.email ?? '',
        phone: user.phoneNumber ?? '',
        avatarUrl: user.photoURL,
      );

      // Send welcome notification for new users
      if (isNewUser) {
        await _sendWelcomeNotification(user.uid, user.displayName ?? 'there');
      }

      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e, st) {
      state = AsyncValue.error(_authErrorMessage(e.code), st);
    } catch (e, st) {
      state = AsyncValue.error('Google sign-in failed. Please try again.', st);
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await gsi.GoogleSignIn().signOut();
    await _auth.signOut();
  }

  // ── Reset Password ───────────────────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _auth.sendPasswordResetEmail(email: email);
      state = const AsyncValue.data(null);
    } on FirebaseAuthException catch (e, st) {
      state = AsyncValue.error(_authErrorMessage(e.code), st);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Creates Firestore user doc only if it doesn't already exist.
  /// Used for social sign-ins so returning users aren't overwritten.
  Future<void> _createUserIfNotExists({
    required String uid,
    required String name,
    required String email,
    required String phone,
    String? avatarUrl,
  }) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      await _saveNewUser(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        role: UserRole.user, // Social sign-ins default to user role
        avatarUrl: avatarUrl,
      );
    }
  }

  Future<void> _sendWelcomeNotification(String uid, String name) async {
    try {
      await _firestore.collection('notifications').add({
        'recipientId': uid,
        'title': '👋 Welcome to HomeEase, $name!',
        'body':
            'We\'re glad you\'re here. Browse trusted service providers near you — plumbers, electricians, cleaners and more.',
        'type': 'welcome',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Add a tips notification shortly after
      await _firestore.collection('notifications').add({
        'recipientId': uid,
        'title': '💡 Getting Started Tip',
        'body':
            'Tap the Services tab to find providers near you. You can filter by category, check ratings, and book instantly.',
        'type': 'tip',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _saveNewUser({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required UserRole role,
    String? avatarUrl,
  }) async {
    final user = UserModel(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      role: role,
      avatarUrl: avatarUrl,
      createdAt: DateTime.now(),
    );
    await _firestore.collection('users').doc(uid).set(user.toFirestore());
    // Send welcome notification for all new email sign-ups
    await _sendWelcomeNotification(uid, name);

    if (role == UserRole.provider) {
      final provider = ProviderModel(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        skills: [],
        bio: '',
        hourlyRate: 0,
        createdAt: DateTime.now(),
      );
      await _firestore
          .collection('providers')
          .doc(uid)
          .set(provider.toFirestore());
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});