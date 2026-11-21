import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/offer_record.dart';
import '../models/product_record.dart';
import '../services/control_room_service.dart';

class OffersController extends GetxController {
  OffersController(this._service);

  final ControlRoomService _service;
  final offers = <OfferRecord>[].obs;
  final products = <ProductRecord>[].obs;
  final loading = true.obs;
  final loadingMore = false.obs;
  final canLoadMore = false.obs;
  final error = RxnString();
  final previewAudience = 'home'.obs;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  DocumentSnapshot<Map<String, dynamic>>? _lastOffer;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    loading.value = true;
    error.value = null;
    _offersSub?.cancel();
    _productsSub?.cancel();
    _offersSub = _service.watchOffers().listen(
      (snapshot) {
        offers.assignAll(
          snapshot.docs.map(
            (doc) => OfferRecord.fromMap(doc.data(), id: doc.id),
          ),
        );
        _lastOffer = snapshot.docs.isEmpty ? null : snapshot.docs.last;
        canLoadMore.value = snapshot.docs.length == ControlRoomService.pageSize;
        loading.value = false;
      },
      onError: (Object exception) {
        error.value = exception.toString();
        loading.value = false;
      },
    );
    _productsSub = _service.watchProducts().listen((snapshot) {
      products.assignAll(
        snapshot.docs.map(
          (doc) => ProductRecord.fromMap(doc.data(), id: doc.id),
        ),
      );
    }, onError: (Object exception) => error.value = exception.toString());
  }

  Future<void> loadMore() async {
    final cursor = _lastOffer;
    if (cursor == null || loadingMore.value) return;
    loadingMore.value = true;
    try {
      final page = await _service.fetchSimplePage('offers', after: cursor);
      offers.addAll(
        page.docs.map((doc) => OfferRecord.fromMap(doc.data(), id: doc.id)),
      );
      _lastOffer = page.docs.isEmpty ? null : page.docs.last;
      canLoadMore.value = page.docs.length == ControlRoomService.pageSize;
    } catch (exception) {
      error.value = exception.toString();
    } finally {
      loadingMore.value = false;
    }
  }

  String productNames(OfferRecord offer) {
    final names = products
        .where((product) => offer.productIds.contains(product.id))
        .take(2)
        .map((product) => product.name)
        .toList();
    final extra = offer.productIds.length - names.length;
    return '${names.join(', ')}${extra > 0 ? ' +$extra' : ''}';
  }

  Future<void> save(OfferRecord offer) async {
    try {
      await _service.saveOffer(offer);
    } catch (exception) {
      error.value = exception.toString();
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _service.deleteOffer(id);
    } catch (exception) {
      error.value = exception.toString();
      rethrow;
    }
  }

  final filter = 'all'.obs;
  final query = ''.obs;

  bool isExpired(OfferRecord o) =>
      o.endsAt != null && o.endsAt!.isBefore(DateTime.now());

  List<OfferRecord> get visible {
    final q = query.value.trim().toLowerCase();
    return offers.where((o) {
      if (q.isNotEmpty &&
          !o.name.toLowerCase().contains(q) &&
          !productNames(o).toLowerCase().contains(q)) {
        return false;
      }
      switch (filter.value) {
        case 'live':
          return o.live && !isExpired(o);
        case 'paused':
          return !o.live && !isExpired(o);
        case 'pinned':
          return o.pinned;
        case 'expired':
          return isExpired(o);
        default:
          return true;
      }
    }).toList();
  }

  @override
  void onClose() {
    _offersSub?.cancel();
    _productsSub?.cancel();
    super.onClose();
  }
}
