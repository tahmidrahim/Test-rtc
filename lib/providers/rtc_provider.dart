import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rtc_enterprise_client.dart';

final rtcSdkProvider = Provider<RtcEnterpriseClientSdk>((ref) {
  return RtcEnterpriseClientSdk(
    apiBaseUrl: 'https://funint.online/api',
    apiKey: 'rtc_api_681cec9d66dff3a48ddda2d4ac209e12a9dad17f218b2353',
  );
});
