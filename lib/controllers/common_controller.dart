import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hoorain_pos/utils/toas_message.dart';

/// All methods are static, so you can call them directly without Get.put():
///   CommonController.openMapsByCoordinates(lat, lng);
class CommonController extends GetxController {
  // --------------------------------------------------------------------
  // Internal helpers
  // --------------------------------------------------------------------

  static Future<bool> _launch(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }

  static void _showError(String message) {
    MessageToast.showError(msg: message, title: 'Error');
  }

  // --------------------------------------------------------------------
  // Web / social
  // --------------------------------------------------------------------

  static Future<void> openUrl(String url) async {
    final ok = await _launch(Uri.parse(url));
    if (!ok) _showError('Could not open the link.');
  }

  // --------------------------------------------------------------------
  // Maps
  // --------------------------------------------------------------------

  /// Opens a ready-made maps URL (e.g. a shop location link).
  static Future<void> launchMaps(String locationUrl) async {
    final ok = await _launch(Uri.parse(locationUrl));
    if (!ok) _showError('Could not open maps. Please check your maps app.');
  }

  /// Opens a pin at the given coordinates (most accurate for deliveries).
  static Future<void> openMapsByCoordinates(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    });
    final ok = await _launch(uri);
    if (!ok) _showError('Could not open maps. Please check your maps app.');
  }

  /// Opens a search for a typed address.
  static Future<void> openMapsByAddress(String address) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': address,
    });
    final ok = await _launch(uri);
    if (!ok) _showError('Could not open maps. Please check your maps app.');
  }

  /// Starts turn-by-turn navigation to the coordinates.
  static Future<void> openMapsDirections(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'driving',
    });
    final ok = await _launch(uri);
    if (!ok) _showError('Could not open maps. Please check your maps app.');
  }
}
