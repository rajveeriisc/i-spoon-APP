import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:smartspoon/features/auth/index.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Email and Password (Firebase Auth)
  ///
  /// AUTH FLOW:
  /// 1. Called from login_screen.dart → _login()
  /// 2. Signs in with Firebase via _auth.signInWithEmailAndPassword
  /// 3. Reloads user to get latest verification status from Firebase
  /// 4. If NOT verified → signs out and returns { needsVerification: true }
  /// 5. If verified → gets fresh ID token via user.getIdToken(true)
  /// 6. Returns { success: true, user, token, emailVerified }
  ///
  /// NEXT STEP: login_screen.dart calls AuthService.verifyFirebaseToken()
  ///            to sync with backend and get backend JWT
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // ✅ Reload user to get latest verification status from Firebase servers
        await user.reload();
        final currentUser = _auth.currentUser;
        
        // Check if email is verified
        if (currentUser != null && !currentUser.emailVerified) {
          await _auth.signOut(); // Sign out unverified user
          return {
            'success': false,
            'message': 'Please verify your email before logging in. Check your inbox.',
            'needsVerification': true,
          };
        }
        
        // ✅ Force refresh the ID token to get updated claims
        final idToken = await currentUser?.getIdToken(true); // true = force refresh
        
        return {
          'success': true,
          'user': {
            'uid': currentUser!.uid,
            'email': currentUser.email,
            'name': currentUser.displayName,
            'avatar_url': currentUser.photoURL,
          },
          'token': idToken!,
          'emailVerified': currentUser.emailVerified,
        };
      }
      throw Exception('User not found');
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  /// Sign up with Email and Password (Firebase Auth)
  ///
  /// AUTH FLOW:
  /// 1. Called from signup_screen.dart → _handleSignUp()
  /// 2. Creates user in Firebase via _auth.createUserWithEmailAndPassword
  /// 3. Updates display name via user.updateDisplayName(name)
  /// 4. Sends verification email via user.sendEmailVerification()
  /// 5. Returns { success: true, user, token, emailVerified: false }
  ///
  /// NEXT STEP: signup_screen.dart shows success message and navigates to LoginScreen
  ///            User must verify email before they can log in
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Update display name
        await user.updateDisplayName(name);

        // ✨ SEND VERIFICATION EMAIL (This was missing!)
        if (!user.emailVerified) {
          await user.sendEmailVerification();
          print('✅ Verification email sent to: $email');
        }

        // Return user data (backend will require verification before issuing JWT)
        return {
          'success': true,
          'user': {
            'uid': user.uid,
            'email': email,
            'name': name,
            'avatar_url': null,
          },
          'token': await user.getIdToken(),
          'emailVerified': user.emailVerified,
        };
      }
      throw Exception('User creation failed');
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  /// Sign in with Google (OAuth)
  ///
  /// AUTH FLOW:
  /// 1. Called from login_screen.dart → _signInWithGoogle()
  /// 2. Opens Google Sign-In dialog via _googleSignIn.signIn()
  /// 3. Gets Google auth credentials (accessToken, idToken)
  /// 4. Signs into Firebase via _auth.signInWithCredential()
  /// 5. Returns { success: true, user, token, firebase_token }
  ///
  /// NEXT STEP: login_screen.dart calls AuthService.verifyFirebaseToken()
  ///            to sync with backend and get backend JWT
  ///            (Google users are auto-verified, no email verification needed)
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        // On web prefer popup-based auth to avoid redirects and blocked popups
        final provider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        // Trigger the authentication flow on mobile/desktop
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return {'success': false, 'message': 'Google sign-in cancelled'};
        }
        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        // Sign in to Firebase with the Google credential
        userCredential = await _auth.signInWithCredential(credential);
      }
      final user = userCredential.user;

      if (user != null) {
        // Return user data from Firebase Auth (no Firestore needed)
        return {
          'success': true,
          'user': {
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName,
            'avatar_url': user.photoURL,
            'auth_provider': 'google',
          },
          'token': await user.getIdToken(),
          'firebase_token': await user.getIdToken(), // For backend verification
        };
      }
      throw Exception('Google sign-in failed');
    } catch (e) {
      return {
        'success': false,
        'message': 'Google sign-in failed: ${e.toString()}',
      };
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await AuthService.requestPasswordReset(email: email);
      return {
        'success': true,
        'message':
            'If an account exists, a reset email has been sent. Check your inbox.',
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
      };
    }
  }

  /// Send Email Verification Link
  ///
  /// AUTH FLOW:
  /// 1. Called from login_screen.dart → _sendEmailVerificationLink()
  /// 2. Gets current Firebase user
  /// 3. Checks if already verified (returns error if yes)
  /// 4. Calls user.sendEmailVerification() - Firebase sends email directly
  /// 5. Returns { success: true, message }
  ///
  /// NEXT STEP: login_screen.dart shows success/error snackbar
  Future<Map<String, dynamic>> sendEmailVerificationLink() async {
    try {
      final user = _auth.currentUser;
      
      if (user == null) {
        return {'success': false, 'message': 'No user logged in'};
      }

      if (user.emailVerified) {
        return {'success': false, 'message': 'Email already verified'};
      }

      await user.sendEmailVerification();
      print('✅ Verification email sent to: ${user.email}');
      
      return {
        'success': true,
        'message': 'Verification email sent! Please check your inbox.',
      };
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        return {
          'success': false,
          'message': 'Too many requests. Please wait a few minutes and try again.',
        };
      }
      return {'success': false, 'message': _getErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send verification email. Please try again.',
      };
    }
  }

  // ✨ Check if current user email is verified (reload from Firebase)
  Future<bool> isEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      await user.reload(); // Refresh user data from Firebase
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      print('Error checking email verification: $e');
      return false;
    }
  }

  // Error message helper - comprehensive handling of all Firebase error codes
  String _getErrorMessage(String code) {
    switch (code) {
      // User not found / Account doesn't exist
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      
      // Wrong password / Invalid credentials
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'invalid-login-credentials':
        return 'Invalid email or password. Please check your credentials.';
      
      // Email related errors
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      
      // Password errors
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters with uppercase, lowercase, number, and special character.';
      
      // Account status
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      
      // Rate limiting / Too many attempts
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a few minutes and try again.';
      
      // Network errors
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      
      // Session expired
      case 'requires-recent-login':
        return 'Please log in again to complete this action.';
      
      // Email verification
      case 'email-not-verified':
        return 'Please verify your email before logging in. Check your inbox.';
      
      // Operation errors
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'popup-closed-by-user':
        return 'Sign-in was cancelled. Please try again.';
      case 'cancelled-popup-request':
        return 'Sign-in popup was closed. Please try again.';
      
      // Token errors
      case 'expired-action-code':
        return 'This link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'This link is invalid. Please request a new one.';
      
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
