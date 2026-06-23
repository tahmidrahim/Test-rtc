import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hapi/providers/user_provider.dart';

/// Handles all Firestore operations related to rooms
class RoomFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save a new room to Firestore
  Future<void> saveRoom({
    required String roomDocumentId,
    required String roomName,
    required int rtcRoomId,
    required UserModel hostUser,
  }) async {
    await _firestore.collection('rooms').doc(roomDocumentId).set({
      'roomId': roomDocumentId,
      'roomName': roomName,
      'hostId': hostUser.id,
      'hostName': hostUser.name,
      'hostPhotoUrl': hostUser.photoUrl ?? '',
      'participants': [hostUser.id],
      'isActive': true,
      'rtcRoomId': rtcRoomId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Load an existing room by roomId
  Future<String?> loadExistingRoom(String requestedRoomId) async {
    if (requestedRoomId.trim().isEmpty) {
      throw Exception('No room selected');
    }

    final doc = await _firestore
        .collection('rooms')
        .where('roomId', isEqualTo: requestedRoomId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (doc.docs.isNotEmpty) {
      return doc.docs.first.id;
    } else {
      throw Exception('Room not found');
    }
  }

  /// Add user to room's participants list
  Future<void> addParticipant(String roomDocumentId, String userId) async {
    try {
      await _firestore.collection('rooms').doc(roomDocumentId).update({
        'participants': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error adding participant: $e');
      rethrow;
    }
  }

  /// Remove user from room and deactivate if empty
  Future<void> removeParticipant(
    String roomDocumentId,
    String userId,
  ) async {
    try {
      final docRef = _firestore.collection('rooms').doc(roomDocumentId);
      final snapshot = await docRef.get();
      final roomData = snapshot.data();

      if (roomData == null) return;

      final participants = List<String>.from(roomData['participants'] ?? []);
      participants.remove(userId);
      final isActive = participants.isNotEmpty;

      await docRef.update({
        'participants': participants,
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!isActive) 'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error removing participant: $e');
      rethrow;
    }
  }

  /// Send a message to room (text or emoji)
  Future<void> sendMessage({
    required String roomDocumentId,
    required String senderId,
    required String senderName,
    required String message,
    String type = 'text',
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomDocumentId)
        .collection('messages')
        .add({
          'senderId': senderId,
          'senderName': senderName,
          'message': message,
          'type': type,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  /// Stream of room data (for participant updates)
  Stream<DocumentSnapshot> streamRoom(String roomDocumentId) {
    return _firestore.collection('rooms').doc(roomDocumentId).snapshots();
  }

  /// Stream of room messages
  Stream<QuerySnapshot> streamMessages(String roomDocumentId) {
    return _firestore
        .collection('rooms')
        .doc(roomDocumentId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
