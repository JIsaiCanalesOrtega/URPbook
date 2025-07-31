import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticateUser() async {
    try {
      // Verificar compatibilidad
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        return false;
      }

      // Mostrar diálogo de autenticación
      bool didAuthenticate = await _auth.authenticate(
        localizedReason:
            'Confirma tu identidad para acceder a marcadores y resaltados',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      print("Error en autenticación biométrica: $e");
      return false;
    }
  }
}
