import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/setting_model.dart';
import '../utils/toas_message.dart';

/// Reads and writes:
///  - settings/store          -> profile + support info
///  - settings/service_config -> delivery radius (km)
class StoreSetupController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _storeDoc =>
      _db.collection('settings').doc('store');
  DocumentReference<Map<String, dynamic>> get _serviceDoc =>
      _db.collection('settings').doc('service_config');

  static const double minRadius = 1;
  static const double maxRadius = 100;

  // ---- UI state -----------------------------------------------------------
  /// Last saved values from Firestore.
  final settings = Rx<StoreSettings>(const StoreSettings());

  final tab = 0.obs;
  final loading = true.obs;
  final error = RxnString();
  final savingProfile = false.obs;
  final savingDelivery = false.obs;
  final savingSupport = false.obs;
  final savingCharges = false.obs;
  final chargesDirty = false.obs;
  final profileDirty = false.obs;
  final deliveryDirty = false.obs;
  final supportDirty = false.obs;

  final profileForm = GlobalKey<FormState>();
  final supportForm = GlobalKey<FormState>();
  final chargesForm = GlobalKey<FormState>();

  // ---- Store profile ------------------------------------------------------
  final name = TextEditingController();
  final taxNumber = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final hours = TextEditingController();

  // ---- Delivery area ------------------------------------------------------
  final radiusText = TextEditingController();
  final radius = 20.0.obs;

  // ---- Support info -------------------------------------------------------
  final supportPhone = TextEditingController();
  final supportWhatsapp = TextEditingController();
  final supportEmail = TextEditingController();
  final supportHours = TextEditingController();

  // ---- Charges & orders ---------------------------------------------------
  final deliveryCharges = TextEditingController();
  final serviceCharges = TextEditingController();
  final freeDelivery = TextEditingController();
  final minimumOrder = TextEditingController();
  Map<String, String> _initialCharges = {};

  /// The charges collection holds one document with an auto id.
  /// It is found on load; if none exists, one is created on first save.
  DocumentReference<Map<String, dynamic>>? _chargesRef;

  Map<String, String> _initialProfile = {};
  Map<String, String> _initialSupport = {};
  double _initialRadius = 20;

  @override
  void onInit() {
    super.onInit();
    for (final c in [name, taxNumber, address, phone, hours]) {
      c.addListener(_checkProfile);
    }
    for (final c in [supportPhone, supportWhatsapp, supportEmail, supportHours]) {
      c.addListener(_checkSupport);
    }
    radiusText.addListener(_onRadiusText);
    for (final c in [deliveryCharges, serviceCharges, freeDelivery, minimumOrder]) {
      c.addListener(_checkCharges);
    }
    load();
  }

  // ------------------------------------------------------------------ load

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final results = await Future.wait([_storeDoc.get(), _serviceDoc.get()]);
      final chargesSnap = await _db.collection('charges').limit(1).get();
      _chargesRef = chargesSnap.docs.isEmpty
          ? null
          : chargesSnap.docs.first.reference;
      final data = StoreSettings.fromMaps(
        store: results[0].data(),
        service: results[1].data(),
        charges: chargesSnap.docs.isEmpty ? null : chargesSnap.docs.first.data(),
      );
      settings.value = data;

      name.text = data.name;
      taxNumber.text = data.taxNumber;
      address.text = data.address;
      phone.text = data.phone;
      hours.text = data.openingHours;

      supportPhone.text = data.supportPhone;
      supportWhatsapp.text = data.supportWhatsapp;
      supportEmail.text = data.supportEmail;
      supportHours.text = data.supportHours;

      _setRadius(data.radius, updateText: true);

      deliveryCharges.text = _amt(data.deliveryCharges);
      serviceCharges.text = _amt(data.serviceCharges);
      freeDelivery.text = _amt(data.freeDeliveryThreshold);
      minimumOrder.text = _amt(data.minimumOrder);

      _snapshotProfile();
      _snapshotSupport();
      _snapshotCharges();
      _initialRadius = radius.value;
      deliveryDirty.value = false;
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  // ----------------------------------------------------------- dirty state

  Map<String, String> _profileNow() => {
    'name': name.text.trim(),
    'tax': taxNumber.text.trim(),
    'address': address.text.trim(),
    'phone': phone.text.trim(),
    'hours': hours.text.trim(),
  };

  Map<String, String> _supportNow() => {
    'phone': supportPhone.text.trim(),
    'wa': supportWhatsapp.text.trim(),
    'email': supportEmail.text.trim(),
    'hours': supportHours.text.trim(),
  };

  void _snapshotProfile() {
    _initialProfile = _profileNow();
    profileDirty.value = false;
  }

  void _snapshotSupport() {
    _initialSupport = _supportNow();
    supportDirty.value = false;
  }

  bool _same(Map<String, String> a, Map<String, String> b) {
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }

  void _checkProfile() => profileDirty.value = !_same(_profileNow(), _initialProfile);
  void _checkSupport() => supportDirty.value = !_same(_supportNow(), _initialSupport);

  // ---------------------------------------------------------------- radius

  void _onRadiusText() {
    final v = double.tryParse(radiusText.text.trim());
    if (v == null) return;
    radius.value = v.clamp(minRadius, maxRadius).toDouble();
    deliveryDirty.value = radius.value != _initialRadius;
  }

  void _setRadius(double value, {bool updateText = false}) {
    final v = value.clamp(minRadius, maxRadius).toDouble();
    radius.value = v;
    if (updateText) radiusText.text = _fmt(v);
    deliveryDirty.value = v != _initialRadius;
  }

  void setRadiusFromSlider(double value) =>
      _setRadius(value.roundToDouble(), updateText: true);

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String? radiusError() {
    final v = double.tryParse(radiusText.text.trim());
    if (v == null) return 'Enter a number';
    if (v < minRadius || v > maxRadius) {
      return 'Use ${_fmt(minRadius)} to ${_fmt(maxRadius)} km';
    }
    return null;
  }

  // ------------------------------------------------------------ discard

  void discardProfile() {
    name.text = _initialProfile['name'] ?? '';
    taxNumber.text = _initialProfile['tax'] ?? '';
    address.text = _initialProfile['address'] ?? '';
    phone.text = _initialProfile['phone'] ?? '';
    hours.text = _initialProfile['hours'] ?? '';
    profileForm.currentState?.reset();
  }

  void discardDelivery() => _setRadius(_initialRadius, updateText: true);

  void discardSupport() {
    supportPhone.text = _initialSupport['phone'] ?? '';
    supportWhatsapp.text = _initialSupport['wa'] ?? '';
    supportEmail.text = _initialSupport['email'] ?? '';
    supportHours.text = _initialSupport['hours'] ?? '';
    supportForm.currentState?.reset();
  }

  // ----------------------------------------------------------------- save

  Future<void> saveProfile() async {
    if (!(profileForm.currentState?.validate() ?? false)) return;
    savingProfile.value = true;
    try {
      final next = settings.value.copyWith(
        name: name.text,
        taxNumber: taxNumber.text,
        address: address.text,
        phone: phone.text,
        openingHours: hours.text,
      );
      await _storeDoc.set(next.toProfileMap(), SetOptions(merge: true));
      settings.value = next;
      _snapshotProfile();
      MessageToast.showToast(msg: 'Store profile saved');
    } catch (e) {
      Get.snackbar('Could not save store profile', e.toString());
    } finally {
      savingProfile.value = false;
    }
  }

  Future<void> saveDelivery() async {
    final problem = radiusError();
    if (problem != null) {
      Get.snackbar('Check the delivery radius', problem);
      return;
    }
    savingDelivery.value = true;
    try {
      final next = settings.value.copyWith(radius: radius.value);
      await _serviceDoc.set(next.toServiceMap(), SetOptions(merge: true));
      settings.value = next;
      _initialRadius = radius.value;
      deliveryDirty.value = false;
      MessageToast.showToast(msg: 'Delivery area saved');
    } catch (e) {
      Get.snackbar('Could not save delivery area', e.toString());
    } finally {
      savingDelivery.value = false;
    }
  }

  Future<void> saveSupport() async {
    if (!(supportForm.currentState?.validate() ?? false)) return;
    savingSupport.value = true;
    try {
      final next = settings.value.copyWith(
        supportPhone: supportPhone.text,
        supportWhatsapp: supportWhatsapp.text,
        supportEmail: supportEmail.text,
        supportHours: supportHours.text,
      );
      await _storeDoc.set(next.toSupportMap(), SetOptions(merge: true));
      settings.value = next;
      _snapshotSupport();
      MessageToast.showToast(msg: 'Support info saved');
    } catch (e) {
      Get.snackbar('Could not save support info', e.toString());
    } finally {
      savingSupport.value = false;
    }
  }

  // ------------------------------------------------------ charges & orders

  String _amt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Map<String, String> _chargesNow() => {
    'delivery': deliveryCharges.text.trim(),
    'service': serviceCharges.text.trim(),
    'free': freeDelivery.text.trim(),
    'min': minimumOrder.text.trim(),
  };

  void _snapshotCharges() {
    _initialCharges = _chargesNow();
    chargesDirty.value = false;
  }

  void _checkCharges() => chargesDirty.value = !_same(_chargesNow(), _initialCharges);

  void discardCharges() {
    deliveryCharges.text = _initialCharges['delivery'] ?? '';
    serviceCharges.text = _initialCharges['service'] ?? '';
    freeDelivery.text = _initialCharges['free'] ?? '';
    minimumOrder.text = _initialCharges['min'] ?? '';
    chargesForm.currentState?.reset();
  }

  Future<void> saveCharges() async {
    if (!(chargesForm.currentState?.validate() ?? false)) return;
    savingCharges.value = true;
    try {
      final next = settings.value.copyWith(
        deliveryCharges: _num(deliveryCharges),
        serviceCharges: _num(serviceCharges),
        freeDeliveryThreshold: _num(freeDelivery),
        minimumOrder: _num(minimumOrder),
      );
      final ref = _chargesRef ?? _db.collection('charges').doc();
      await ref.set(next.toChargesMap(), SetOptions(merge: true));
      _chargesRef = ref;
      settings.value = next;
      _snapshotCharges();
      MessageToast.showToast(msg: 'Charges and minimum order saved');
    } catch (e) {
      Get.snackbar('Could not save charges', e.toString());
    } finally {
      savingCharges.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in [
      name, taxNumber, address, phone, hours, radiusText,
      supportPhone, supportWhatsapp, supportEmail, supportHours,
      deliveryCharges, serviceCharges, freeDelivery, minimumOrder,
    ]) {
      c.dispose();
    }
    super.onClose();
  }
}