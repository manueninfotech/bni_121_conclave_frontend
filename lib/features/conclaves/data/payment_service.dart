import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/config/api_config.dart';

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(FirebaseAuth.instance);
});

/// A Razorpay order minted by the backend. The app never computes the amount or
/// holds the secret — it receives the public [key] and an [orderId] to open.
class RazorpayOrder {
  final String orderId;

  /// Paise (Razorpay's unit), as returned by the backend.
  final int amount;
  final String currency;

  /// The public Razorpay key_id. Safe to hold on the client.
  final String key;

  const RazorpayOrder({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.key,
  });
}

/// The proof of a completed payment, handed back to `/register` for the backend
/// to verify (signature AND captured amount) before it will seat the member.
class PaymentProof {
  final String orderId;
  final String paymentId;
  final String signature;

  const PaymentProof({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
        'method': 'online',
        'orderId': orderId,
        'paymentId': paymentId,
        'signature': signature,
      };
}

/// Online payment isn't available (keys not configured on the server, or the
/// endpoint isn't deployed yet). The caller should offer offline payment.
class PaymentUnavailable implements Exception {
  final String message;
  PaymentUnavailable(this.message);
  @override
  String toString() => message;
}

/// The member dismissed the Razorpay sheet, or it failed. Distinct from
/// [PaymentUnavailable] so the UI can say "cancelled" vs "not available".
class PaymentCancelled implements Exception {
  final String message;
  PaymentCancelled(this.message);
  @override
  String toString() => message;
}

class PaymentService {
  final FirebaseAuth _auth;
  final Dio _dio = Dio(BaseOptions(
    // Generous: the backend may cold-start (~30s on a sleeping free tier), and
    // opening a Razorpay order is a step the member is actively waiting on.
    connectTimeout: const Duration(seconds: 45),
    receiveTimeout: const Duration(seconds: 45),
  ));

  PaymentService(this._auth);

  /// Ask the backend to open a Razorpay order for this conclave's fee.
  ///
  /// Throws [PaymentUnavailable] on a 503 (keys unset) or 404 (endpoint not
  /// deployed) so the caller falls back to offline payment instead of dead-ending.
  Future<RazorpayOrder> createOrder(String conclaveId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be logged in to pay.');
    final token = await user.getIdToken();

    try {
      final res = await _dio.post(
        '${ApiConfig.baseUrl}/conclaves/$conclaveId/payment/order',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data as Map;
      return RazorpayOrder(
        orderId: data['orderId'] as String,
        amount: (data['amount'] as num).toInt(),
        currency: (data['currency'] ?? 'INR') as String,
        key: data['key'] as String,
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? data['error'] as String
          : 'Could not start the payment.';
      if (code == 503 || code == 404) throw PaymentUnavailable(msg);
      throw Exception(msg);
    }
  }

  /// Open the Razorpay checkout and resolve with a [PaymentProof] on success.
  ///
  /// Razorpay's plugin is event-driven; this bridges it to a Future. Exactly one
  /// of success/error/wallet fires per open, and the listeners are torn down in
  /// `finally` so a second payment doesn't inherit stale handlers.
  Future<PaymentProof> openCheckout({
    required RazorpayOrder order,
    required String conclaveName,
    String? prefillEmail,
    String? prefillContact,
  }) {
    final razorpay = Razorpay();
    final completer = Completer<PaymentProof>();

    void finish(void Function() action) {
      if (!completer.isCompleted) action();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      // All three are required for the backend to verify. If any is missing the
      // payment can't be proven, so treat it as a failure rather than register
      // an unverifiable seat.
      final id = r.paymentId, ord = r.orderId, sig = r.signature;
      finish(() {
        if (id == null || ord == null || sig == null) {
          completer.completeError(
            PaymentCancelled('Payment could not be confirmed. If money was '
                'deducted it will be refunded automatically.'),
          );
        } else {
          completer.complete(
            PaymentProof(orderId: ord, paymentId: id, signature: sig),
          );
        }
      });
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      finish(() => completer.completeError(
            PaymentCancelled(r.message ?? 'Payment was cancelled.'),
          ));
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      // The member left to complete payment in a wallet app; we can't confirm it
      // here. Fail closed — they can retry or pay offline.
      finish(() => completer.completeError(
            PaymentCancelled('Complete the payment in your wallet app, then try again.'),
          ));
    });

    try {
      razorpay.open({
        'key': order.key,
        'order_id': order.orderId,
        'amount': order.amount, // paise
        'currency': order.currency,
        'name': 'BNI 121 Conclave',
        'description': 'Registration — $conclaveName',
        'prefill': {
          'email': ?prefillEmail,
          'contact': ?prefillContact,
        },
        'timeout': 300, // seconds
      });
    } catch (e) {
      finish(() => completer.completeError(
            PaymentCancelled('Could not open the payment screen: $e'),
          ));
    }

    return completer.future.whenComplete(() {
      // clear() removes listeners and releases the native handler.
      razorpay.clear();
    });
  }
}
