import 'rtc_interface.dart';
import 'rtc_service.dart';

class RTCFactory {
  static IRTCService create() {
    return RTCService();
  }
}
