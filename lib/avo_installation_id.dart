import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AvoInstallationId {

  static String? _installationId;

  static const installationIdKey = "AvoInspectorInstallationId";

  static String getInstallationId(SharedPreferences sharedPrefs) {
    if (AvoInstallationId._installationId != null) {
      return AvoInstallationId._installationId!;
    }

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