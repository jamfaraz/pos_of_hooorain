import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/order_model.dart';
import '../utils/get_server_key.dart';

class LocalNotificationService {
  //initialising firebase message plugin
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  //initialising firebase message plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  //send notificartion request
  void requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('user granted permission');
      }
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      if (kDebugMode) {
        print('user granted provisional permission');
      }
    } else {
      //appsetting.AppSettings.openNotificationSettings();
      if (kDebugMode) {
        print('user denied permission');
      }
    }
  }

  //Fetch FCM Token
  Future<String> getDeviceToken() async {
    String? token = await messaging.getToken();
    print("token=> $token");
    return token!;
  }

  //function to initialise flutter local notification plugin to show notifications for android when app is active
  void initLocalNotifications(
    BuildContext context,
    RemoteMessage message,
  ) async {
    var androidInitializationSettings = const AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    var iosInitializationSettings = const DarwinInitializationSettings();

    var initializationSetting = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSetting,
      onDidReceiveNotificationResponse: (payload) {
        // handle interaction when app is active for android
        handleMessage(context, message);
      },
    );
  }

  //
  void firebaseInit(BuildContext context) {
    FirebaseMessaging.onMessage.listen((message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification!.android;

      if (kDebugMode) {
        print("notifications title:${notification!.title}");
        print("notifications body:${notification.body}");
        print('count:${android!.count}');
        print('data:${message.data.toString()}');
      }

      if (Platform.isIOS) {
        forgroundMessage();
      }

      if (Platform.isAndroid) {
        initLocalNotifications(context, message);
        showNotification(message);
      }
    });
  }

  //handle tap on notification when app is in background or terminated
  Future<void> setupInteractMessage(BuildContext context) async {
    // // when app is terminated
    // RemoteMessage? initialMessage =
    //     await FirebaseMessaging.instance.getInitialMessage();

    // if (initialMessage != null) {
    //   handleMessage(context, initialMessage);
    // }

    //when app ins background
    FirebaseMessaging.onMessageOpenedApp.listen((event) {
      handleMessage(context, event);
    });

    // Handle terminated state
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null && message.data.isNotEmpty) {
        handleMessage(context, message);
      }
    });
  }

  // function to show visible notification when app is active
  Future<void> showNotification(RemoteMessage message) async {
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      message.notification!.android!.channelId.toString(),
      message.notification!.android!.channelId.toString(),
      importance: Importance.max,
      showBadge: true,
      playSound: true,
      // sound: const RawResourceAndroidNotificationSound('jetsons_doorbell'),
    );

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          channel.id.toString(),
          channel.name.toString(),
          channelDescription: 'your channel description',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          ticker: 'ticker',
          sound: channel.sound,
          //     sound: RawResourceAndroidNotificationSound('jetsons_doorbell')
          //  icon: largeIconPath
        );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    Future.delayed(Duration.zero, () {
      _flutterLocalNotificationsPlugin.show(
        id: 0,
        title: message.notification!.title.toString(),
        body: message.notification!.body.toString(),
        notificationDetails: notificationDetails,
        payload: 'my_data',
      );
    });
  }

  Future forgroundMessage() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // Inside LocalNotificationService class
  Future<void> handleMessage(
    BuildContext context,
    RemoteMessage message,
  ) async {
    String screen = message.data['screen'] ?? '';

    if (screen == 'order_detail') {
      String? orderId = message.data['orderId'];

      if (orderId != null) {
        // 🚨 Use the function to fetch the full order data
        OrderModel? order = await fetchOrderDetails(orderId);

        if (order != null) {
          Get.toNamed('/orders/detail', arguments: order);
          return; // Exit if navigation is successful
        }
      }
    }

    // // Fallback for other screens or if order data retrieval fails
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (context) => NotificationScreen()),
    // );
  }

  // Assuming OrderModel has a factory constructor for Firestore snapshots
  Future<OrderModel?> fetchOrderDetails(String orderId) async {
    try {
      final orderSnapshot = await FirebaseFirestore.instance
          .collection('orders') // Collection where you store orders
          .doc(orderId) // The orderId sent in the notification data
          .get();

      if (orderSnapshot.exists) {
        // ✅ CORRECTED LINE: Safely cast the data() to Map<String, dynamic>
        final orderData = orderSnapshot.data();

        if (orderData != null) {
          // Assuming OrderModel has a fromMap factory method that takes Map<String, dynamic> and doc ID
          return OrderModel.fromMap(
            orderData, // Pass the Map data
            orderSnapshot.id,
          );
        }
      }
      return null; // Order not found or data is null
    } catch (e) {
      print('Error fetching order details for $orderId: $e');
      return null;
    }
  }

  static Future<void> sendNotificationUsingApi({
    required String? token,
    required String? title,
    required String? body,
    required Map<String, dynamic>? data,
  }) async {
    String serverKey = await GetServerKey().getServerKeyToken();
    print("notification server key => ${serverKey}");
    String url =
        "https://fcm.googleapis.com/v1/projects/hoorain-ae51a/messages:send";

    var headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $serverKey',
    };

    //mesaage
    Map<String, dynamic> message = {
      "message": {
        "token": token,
        "notification": {"body": body, "title": title},
        "data": data,
      },
    };

    //hit api
    final http.Response response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print("Notification Send Successfully!");
    } else {
      print("Notification not send!");
    }
  }
}
