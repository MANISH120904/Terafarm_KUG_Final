import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'l10n/app_locales.dart';
import 'main.dart' show LocaleProvider;
import 'theme/tera_farm_theme.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({Key? key}) : super(key: key);

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final double _tileHeight = 96.0;
  int _currentUserIndex = -1;
  bool _showFloatingYou = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_currentUserIndex == -1) return;
    final viewportStart = _scrollController.offset;
    final viewportEnd =
        _scrollController.offset + MediaQuery.of(context).size.height;
    final itemOffset = _currentUserIndex * _tileHeight;

    final isVisible = itemOffset >= viewportStart && itemOffset < viewportEnd;
    if (isVisible && _showFloatingYou) {
      setState(() => _showFloatingYou = false);
    } else if (!isVisible && !_showFloatingYou) {
      setState(() => _showFloatingYou = true);
    }
  }

  Future<QuerySnapshot> _fetchUsers(
    bool isGlobal,
    String? currentUserLocation,
  ) {
    final usersRef = FirebaseFirestore.instance.collection('users');
    Query query = usersRef.orderBy('xp', descending: true);
    if (!isGlobal && currentUserLocation != null) {
      query = query.where('location', isEqualTo: currentUserLocation);
    }
    return query.get();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProv = Provider.of<LocaleProvider>(context, listen: false);

    final currentUserLocation = null; // fetch if you have it

    return Scaffold(
      backgroundColor: TeraFarmColors.surface,
      appBar: AppBar(
        title: Text(
          loc.leaderboardTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: TeraFarmColors.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: TeraFarmColors.primary.withOpacity(0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language, color: Colors.white),
            tooltip: 'Language',
            onSelected: (locale) => localeProv.setLocale(locale),
            itemBuilder: (context) => AppLocales.supported
                .map(
                  (l) => PopupMenuItem(
                    value: l,
                    child: Text(l.languageCode.toUpperCase()),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(loc.tabGlobal),
              ),
            ),
            Tab(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(loc.tabLocal),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildLeaderboard(
              isGlobal: true,
              loc: loc,
              currentUserLocation: currentUserLocation,
            ),
            _buildLeaderboard(
              isGlobal: false,
              loc: loc,
              currentUserLocation: currentUserLocation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard({
    required bool isGlobal,
    required AppLocalizations loc,
    String? currentUserLocation,
  }) {
    return FutureBuilder<QuerySnapshot>(
      future: _fetchUsers(isGlobal, currentUserLocation),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF246B40)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.loading,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF246B40),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade50,
                    Colors.red.shade100,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.errorLoadingLeaderboard,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        _currentUserIndex = docs.indexWhere(
          (doc) => doc.id == FirebaseAuth.instance.currentUser?.uid,
        );

        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final userData = docs[index].data()! as Map<String, dynamic>;
                  final rank = index + 1;
                  final isCurrent =
                      docs[index].id == FirebaseAuth.instance.currentUser?.uid;
                  return _buildAnimatedTile(
                    index,
                    _leaderboardTile(loc, rank, userData, isCurrent),
                  );
                },
              ),
            ),
            if (_showFloatingYou && _currentUserIndex != -1)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _floatingCurrentUser(loc, docs[_currentUserIndex]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedTile(int index, Widget child) {
    final delay = Duration(milliseconds: 300 + index * 100);
    return AnimatedSlide(
      offset: const Offset(0, 0.3),
      duration: delay,
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: delay,
        opacity: 1,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: _tileHeight),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _leaderboardTile(
    AppLocalizations loc,
    int rank,
    Map<String, dynamic> userData,
    bool isCurrent,
  ) {
    Color rankColor = Colors.grey.shade600;
    IconData? rankIcon;
    
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.emoji_events;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: isCurrent
            ? LinearGradient(
                colors: [
                  const Color(0xFF246B40).withOpacity(0.1),
                  const Color(0xFF246B40).withOpacity(0.05),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(
                color: const Color(0xFF246B40).withOpacity(0.3),
                width: 2,
              )
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF246B40),
                const Color(0xFF246B40).withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF246B40).withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundImage: userData['profileImage'] != null
                ? NetworkImage(userData['profileImage'])
                : null,
            backgroundColor: Colors.transparent,
            child: userData['profileImage'] == null
                ? const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
        ),
        title: Text(
          userData['username'] ?? loc.unknownUser,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isCurrent ? const Color(0xFF246B40) : Colors.black87,
          ),
        ),
        subtitle: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF246B40).withOpacity(0.1),
                const Color(0xFF246B40).withOpacity(0.05),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${userData['xp'] ?? 0} XP',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF246B40),
            ),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: rank <= 3
                  ? [rankColor, rankColor.withOpacity(0.8)]
                  : [
                      Colors.grey.shade200,
                      Colors.grey.shade300,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: rankColor.withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rankIcon != null)
                Icon(
                  rankIcon,
                  color: rank <= 3 ? Colors.white : Colors.grey.shade600,
                  size: 18,
                ),
              if (rankIcon != null) const SizedBox(width: 4),
              Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: rank <= 3 ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingCurrentUser(AppLocalizations loc, DocumentSnapshot doc) {
    final userData = doc.data()! as Map<String, dynamic>;
    final rank = _currentUserIndex + 1;
    
    Color rankColor = Colors.grey.shade600;
    IconData? rankIcon;
    
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.emoji_events;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF246B40),
            const Color(0xFF246B40).withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF246B40).withOpacity(0.4),
            blurRadius: 16,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundImage: userData['profileImage'] != null
                  ? NetworkImage(userData['profileImage'])
                  : null,
              backgroundColor: Colors.grey.shade100,
              child: userData['profileImage'] == null
                  ? Icon(
                      Icons.person,
                      color: Colors.grey.shade600,
                      size: 24,
                    )
                  : null,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  userData['username'] ?? loc.youLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${userData['xp'] ?? 0} XP',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: rank <= 3
                    ? [rankColor, rankColor.withOpacity(0.8)]
                    : [
                        Colors.white,
                        Colors.white.withOpacity(0.9),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rankIcon != null)
                  Icon(
                    rankIcon,
                    color: rank <= 3 ? Colors.white : const Color(0xFF246B40),
                    size: 18,
                  ),
                if (rankIcon != null) const SizedBox(width: 4),
                Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: rank <= 3 ? Colors.white : const Color(0xFF246B40),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
