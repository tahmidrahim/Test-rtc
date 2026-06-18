import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hapi/providers/navigation_provider.dart';
import 'package:hapi/providers/user_provider.dart';

import 'package:hapi/screens/game/game_screen.dart';
import 'package:hapi/screens/home/profile_screen.dart';
import 'package:hapi/screens/message/message_screen.dart';
import 'package:hapi/providers/call_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hapi/screens/test_screen.dart';

final dailyRewardShownProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTab = 0;
  String _selectedCategory = 'Popular';

  final List<Widget> _screens = [
    const HomeContent(),
    const MessageScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hasShown = ref.read(dailyRewardShownProvider);
      if (!hasShown) {
        _showDailyRewardPopup();
      }
    });
  }

  void _showDailyRewardPopup() {
    ref.read(dailyRewardShownProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    final activeCallRoomId = ref.watch(activeCallProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: activeCallRoomId != null
          ? FloatingActionButton(
              onPressed: () {
                ref
                    .read(navigationProvider.notifier)
                    .goToVoiceRoom(roomId: activeCallRoomId, isCreating: false);
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.call, color: Colors.white),
            )
          : FloatingActionButton(
              onPressed: () =>
                  ref.read(navigationProvider.notifier).goToEditRoomName(),
              backgroundColor: const Color(0xFF1DE9B6),
              child: const Icon(Icons.mic, color: Colors.white),
            ),
      body: _screens[_selectedTab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        selectedItemColor: const Color(0xFF1DE9B6),
        onTap: (index) => setState(() => _selectedTab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Message'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}

class HomeContent extends ConsumerStatefulWidget {
  const HomeContent({super.key});

  @override
  ConsumerState<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<HomeContent> {
  String _selectedCategory = 'Popular';

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildEventBanner(),
                const SizedBox(height: 16),
                _buildQuickAccessGrid(),
                const SizedBox(height: 16),
                _buildTabSwitch(),
              ],
            ),
          ),
        ),
        _buildSelectedContent(),
      ],
    );
  }

  Widget _buildSelectedContent() {
    if (_selectedCategory == 'Game') {
      return SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: SliverToBoxAdapter(child: GameContent()),
      );
    }
    return _buildLiveRoomsStream();
  }

  Widget _buildLiveRoomsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Error: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final rooms = snapshot.data?.docs ?? [];

        if (rooms.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.people, size: 50, color: Colors.grey),
                    const SizedBox(height: 5),
                    const Text('No active rooms'),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              final roomData = room.data() as Map<String, dynamic>;
              return _buildRoomCard(room.id, roomData);
            },
          ),
        );
      },
    );
  }

  Widget _buildRoomCard(String roomId, Map<String, dynamic> room) {
    final currentUserId = ref.read(userProvider).id;
    final isHost = room['hostId'] == currentUserId;

    return GestureDetector(
      onTap: () {
        ref
            .read(navigationProvider.notifier)
            .goToVoiceRoom(roomId: roomId, isCreating: false);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Host Avatar or Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child:
                    room['hostPhotoUrl'] != null &&
                        room['hostPhotoUrl'].toString().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: room['hostPhotoUrl'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        room['hostName'] ?? 'Unknown Host',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isHost) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DE9B6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'HOST',
                            style: TextStyle(color: Colors.white, fontSize: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room['roomName'] ?? 'Room',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.people,
                        size: 12,
                        color: Color(0xFF1DE9B6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(room['participants'] as List?)?.length ?? 1}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: const Color(0xFF1DE9B6),
      elevation: 0,
      title: const Text("Hapi", style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEventBanner() {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "LEVEL UP RACING",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "FOR COINS",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: const Text("Go"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    return Row(
      children: [
        _quickTile("Ranking", Colors.cyan[50]!, Colors.cyan),
        const SizedBox(width: 8),
        _quickTile("Family", Colors.orange[50]!, Colors.orange),
        const SizedBox(width: 8),
        _quickTile("CP / Friend", Colors.purple[50]!, Colors.purple),
      ],
    );
  }

  Widget _quickTile(String label, Color bg, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.star_outline, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitch() {
    final tabs = ['Popular', 'Game', 'Video/Music'];
    return Row(
      children: tabs.map((tab) {
        bool isSelected = _selectedCategory == tab;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => setState(() => _selectedCategory = tab),
            child: Column(
              children: [
                Text(
                  tab,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.grey,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (isSelected)
                  Container(
                    height: 2,
                    width: 20,
                    color: const Color(0xFF1DE9B6),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
