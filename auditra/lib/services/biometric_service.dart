import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // Check if device supports biometric authentication
  static Future<bool> isDeviceSupported() async {
    try {
      // Check if device is supported
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        print('BiometricService: Device does not support biometrics');
        return false;
      }
      
      // Check if biometrics can be checked (permissions and hardware)
      final canCheck = await _localAuth.canCheckBiometrics;
      print('BiometricService: Device supported: $isSupported, Can check: $canCheck');
      return canCheck;
    } catch (e) {
      print('BiometricService: Error checking device support: $e');
      return false;
    }
  }

  // Check if biometrics are available (hardware + permissions)
  static Future<Map<String, dynamic>> checkBiometricAvailability() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      final isAvailable = isSupported && canCheck && availableBiometrics.isNotEmpty;
      
      print('BiometricService: Availability check -');
      print('  isSupported: $isSupported');
      print('  canCheck: $canCheck');
      print('  hasBiometrics: ${availableBiometrics.isNotEmpty}');
      print('  availableTypes: $availableBiometrics');
      print('  isAvailable: $isAvailable');
      
      return {
        'isSupported': isSupported,
        'canCheck': canCheck,
        'hasBiometrics': availableBiometrics.isNotEmpty,
        'availableTypes': availableBiometrics,
        'isAvailable': isAvailable,
      };
    } catch (e) {
      print('BiometricService: Error checking availability: $e');
      return {
        'isSupported': false,
        'canCheck': false,
        'hasBiometrics': false,
        'availableTypes': <BiometricType>[],
        'isAvailable': false,
        'error': e.toString(),
      };
    }
  }

  // Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Note: Biometric enabled status is now checked from database via API

  // Store username for biometric login (password not needed - handled by backend)
  static Future<void> storeUsernameForBiometric(String username) async {
    await _secureStorage.write(key: 'biometric_username', value: username);
  }

  // Get stored username for biometric login
  static Future<String?> getStoredUsername() async {
    return await _secureStorage.read(key: 'biometric_username');
  }

  // Disable biometric authentication (clear local storage)
  static Future<void> clearBiometricStorage() async {
    await _secureStorage.delete(key: 'biometric_username');
  }

  // Authenticate using biometric with proper permission handling
  static Future<Map<String, dynamic>> authenticateWithResult({
    String reason = 'Authenticate to continue',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // First check if device supports biometrics
      final availability = await checkBiometricAvailability();
      
      if (!availability['isAvailable'] as bool) {
        String errorMessage = 'Biometric authentication is not available';
        if (!availability['isSupported'] as bool) {
          errorMessage = 'Your device does not support biometric authentication';
        } else if (!availability['canCheck'] as bool) {
          errorMessage = 'Biometric permission not granted. Please enable it in device settings.';
        } else if (!availability['hasBiometrics'] as bool) {
          errorMessage = 'No biometric data enrolled. Please set up fingerprint or face unlock in device settings.';
        }
        
        return {
          'success': false,
          'error': errorMessage,
          'availability': availability,
        };
      }

      // Attempt authentication
      print('BiometricService: Attempting authentication...');
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true, // Only use biometric, not device PIN/pattern
        ),
      );

      print('BiometricService: Authentication result: $authenticated');
      
      if (!authenticated) {
        // User likely cancelled or authentication failed
        return {
          'success': false,
          'error': 'Biometric authentication was cancelled or failed. Please try again.',
          'code': 'UserCancel',
        };
      }
      
      return {
        'success': true,
        'error': null,
      };
    } on PlatformException catch (e) {
      String errorMessage = 'Biometric authentication failed';
      
      if (e.code == 'NotAvailable') {
        errorMessage = 'Biometric authentication is not available on this device';
      } else if (e.code == 'NotEnrolled') {
        errorMessage = 'No biometric data enrolled. Please set up fingerprint or face unlock in device settings.';
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        errorMessage = 'Biometric authentication is locked. Please use your device PIN/pattern to unlock.';
      } else if (e.code == 'UserCancel') {
        errorMessage = 'Authentication cancelled by user';
      } else {
        errorMessage = e.message ?? 'Biometric authentication error';
      }
      
      return {
        'success': false,
        'error': errorMessage,
        'code': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Unexpected error: ${e.toString()}',
      };
    }
  }

  // Simplified authenticate method (backward compatibility)
  static Future<bool> authenticate({
    String reason = 'Authenticate to continue',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    final result = await authenticateWithResult(
      reason: reason,
      useErrorDialogs: useErrorDialogs,
      stickyAuth: stickyAuth,
    );
    return result['success'] as bool? ?? false;
  }

  // Check if username is stored for biometric login
  static Future<bool> hasStoredUsername() async {
    final username = await getStoredUsername();
    return username != null;
  }

  // Get biometric type name for display
  static String getBiometricTypeName(List<BiometricType> types) {
    if (types.isEmpty) return 'Biometric';
    if (types.contains(BiometricType.face)) return 'Face ID';
    if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (types.contains(BiometricType.strong)) return 'Biometric';
    if (types.contains(BiometricType.weak)) return 'Biometric';
    return 'Biometric';
  }
}


