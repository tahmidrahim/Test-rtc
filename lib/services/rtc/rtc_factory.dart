import 'package:hapi/services/rtc/funint_rtc_service.dart';

import 'rtc_interface.dart';
// import 'rtc_service.dart';

class RTCFactory {
  static IRTCService create() {
    // return RTCService();
    return FunintRtcService();
  }
}
