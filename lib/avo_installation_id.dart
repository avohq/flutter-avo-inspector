import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AvoInstallationId {

  static String? _installationId;

  static const installationIdKey = "AvoInspectorInstallationId";

  static Future<String> getInstallationId() async {
    if (AvoInstallationId._installationId != null) {
      return AvoInstallationId._installationId!;
    }

    final sharedPrefs = await SharedPreferences.getInstance();

    final storedInstallationId = sharedPrefs.getString(installationIdKey);
    
    if (storedInstallationId != null) {
      AvoInstallationId._installationId = storedInstallationId;
      return storedInstallationId;
    } else {
      final newInstallationId = Uuid().v1();
      AvoInstallationId._installationId = newInstallationId;
      sharedPrefs.setString(AvoInstallationId.installationIdKey, newInstallationId);
      return newInstallationId;
    }
  }
}