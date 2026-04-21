import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

  List<UserModel> _users = [];
  bool _loadingUsers = true;
  String _searchQuery = '';
  String _roleFilter = 'all';

  // Stats
  int _totalPatients = 0;
  int _totalNurses = 0;
  int _totalConversations = 0;
  int _totalRequests = 0;
  int _acceptedRequests = 0;
  int _declinedRequests = 0;
  int _pendingRequests = 0;
  int _endedRequests = 0;
  int _normalRequests = 0;
  int _emergencyRequests = 0;
  int _disabledUsers = 0;
  int _newUsersThisMonth = 0;

  StreamSubscription? _usersSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _listenUsers();
    _loadStats();
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _listenUsers() {
    _usersSub = _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      setState(() {
        _users = snap.docs
            .map((d) => UserModel.fromFirestore(d))
            .where((u) => u.role != UserRole.superAdmin)
            .toList();
        _loadingUsers = false;
      });
    });
  }

  Future<void> _loadStats() async {
    final now = DateTime.now();
    final startOfMonth = Timestamp.fromDate(DateTime(now.year, now.month, 1));
    final results = await Future.wait([
      _db.collection('users').where('role', isEqualTo: 'patient').count().get(),                                                   // 0
      _db.collection('users').where('role', isEqualTo: 'nurse').count().get(),                                                    // 1
      _db.collection('conversations').count().get(),                                                                               // 2
      _db.collection('chat_requests').count().get(),                                                                               // 3
      _db.collection('chat_requests').where('status', isEqualTo: 'accepted').count().get(),                                       // 4
      _db.collection('chat_requests').where('status', isEqualTo: 'declined').count().get(),                                       // 5
      _db.collection('chat_requests').where('status', isEqualTo: 'ended').count().get(),                                          // 6
      _db.collection('chat_requests').where('urgency', isEqualTo: 'emergency').count().get(),                                     // 7
      _db.collection('users').where('isDisabled', isEqualTo: true).count().get(),                                                 // 8
      _db.collection('users').where('createdAt', isGreaterThanOrEqualTo: startOfMonth).count().get(),                             // 9
    ]);
    if (!mounted) return;
    final total = results[3].count ?? 0;
    final accepted = results[4].count ?? 0;
    final declined = results[5].count ?? 0;
    final ended = results[6].count ?? 0;
    final emergency = results[7].count ?? 0;
    setState(() {
      _totalPatients = results[0].count ?? 0;
      _totalNurses = results[1].count ?? 0;
      _totalConversations = results[2].count ?? 0;
      _totalRequests = total;
      _acceptedRequests = accepted;
      _declinedRequests = declined;
      _endedRequests = ended;
      _pendingRequests = max(0, total - accepted - declined - ended);
      _emergencyRequests = emergency;
      _normalRequests = max(0, total - emergency);
      _disabledUsers = results[8].count ?? 0;
      _newUsersThisMonth = results[9].count ?? 0;
    });
  }

  List<UserModel> get _filteredUsers {
    return _users.where((u) {
      final matchesRole = _roleFilter == 'all' || u.roleString == _roleFilter;
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
      return matchesRole && matchesSearch;
    }).toList();
  }

  Future<void> _updatePassword(UserModel user) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text('Reset password for ${user.name}',
            style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 16)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          style: const TextStyle(color: Color(0xFFE6EDF3)),
          decoration: InputDecoration(
            labelText: 'New password',
            labelStyle: const TextStyle(color: Color(0xFF8B949E)),
            enabledBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: const Color(0xFF30363D).withOpacity(0.6)),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF00BFA5)),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8B949E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update',
                style: TextStyle(color: Color(0xFF00BFA5))),
          ),
        ],
      ),
    );

    if (confirmed != true || ctrl.text.isEmpty || !mounted) return;

    try {
      final callable = _functions.httpsCallable('updateUserPassword');
      await callable.call({'uid': user.uid, 'newPassword': ctrl.text});
      if (!mounted) return;
      _showSnack('Password updated for ${user.name}', success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed: $e', success: false);
    }
  }

  Future<void> _toggleDisable(UserModel user) async {
    final action = user.isDisabled ? 'enable' : 'disable';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text('${action[0].toUpperCase()}${action.substring(1)} account?',
            style: const TextStyle(color: Color(0xFFE6EDF3))),
        content: Text('This will $action ${user.name}\'s account.',
            style: const TextStyle(color: Color(0xFF8B949E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8B949E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action[0].toUpperCase() + action.substring(1),
                style: const TextStyle(color: Color(0xFFCF6679))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final callable = _functions.httpsCallable(
          user.isDisabled ? 'enableUser' : 'disableUser');
      await callable.call({'uid': user.uid});
      if (!mounted) return;
      _showSnack(
          '${user.name} has been ${user.isDisabled ? 'enabled' : 'disabled'}.',
          success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed: $e', success: false);
    }
  }

  Future<void> _editName(UserModel user) async {
    final ctrl = TextEditingController(text: user.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Edit name',
            style: TextStyle(color: Color(0xFFE6EDF3))),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Color(0xFFE6EDF3)),
          decoration: InputDecoration(
            labelText: 'Name',
            labelStyle: const TextStyle(color: Color(0xFF8B949E)),
            enabledBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: const Color(0xFF30363D).withOpacity(0.6)),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF00BFA5)),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8B949E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save',
                style: TextStyle(color: Color(0xFF00BFA5))),
          ),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.isEmpty || !mounted) return;
    await _db.collection('users').doc(user.uid).update({'name': ctrl.text});
    _showSnack('Name updated.', success: true);
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF00BFA5) : const Color(0xFFCF6679),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final adminName = context.read<AuthProvider>().user?.name ?? 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings,
                  size: 18, color: Color(0xFF00BFA5)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Admin Panel',
                    style: TextStyle(
                        color: Color(0xFFE6EDF3),
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Text(adminName,
                    style: const TextStyle(
                        color: Color(0xFF8B949E), fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8B949E)),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BFA5),
          labelColor: const Color(0xFF00BFA5),
          unselectedLabelColor: const Color(0xFF8B949E),
          tabs: const [
            Tab(icon: Icon(Icons.people_outline, size: 20), text: 'Users'),
            Tab(icon: Icon(Icons.bar_chart_outlined, size: 20), text: 'Stats'),
            Tab(
                icon: Icon(Icons.chat_bubble_outline, size: 20),
                text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UsersTab(
            users: _filteredUsers,
            loading: _loadingUsers,
            searchQuery: _searchQuery,
            roleFilter: _roleFilter,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onRoleFilterChanged: (v) => setState(() => _roleFilter = v),
            onEditName: _editName,
            onUpdatePassword: _updatePassword,
            onToggleDisable: _toggleDisable,
          ),
          _StatsTab(
            totalPatients: _totalPatients,
            totalNurses: _totalNurses,
            totalConversations: _totalConversations,
            totalRequests: _totalRequests,
            acceptedRequests: _acceptedRequests,
            declinedRequests: _declinedRequests,
            pendingRequests: _pendingRequests,
            endedRequests: _endedRequests,
            normalRequests: _normalRequests,
            emergencyRequests: _emergencyRequests,
            disabledUsers: _disabledUsers,
            newUsersThisMonth: _newUsersThisMonth,
            onRefresh: _loadStats,
          ),
          const _RequestsTab(),
        ],
      ),
    );
  }
}

// ── Users Tab ─────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final List<UserModel> users;
  final bool loading;
  final String searchQuery;
  final String roleFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRoleFilterChanged;
  final Future<void> Function(UserModel) onEditName;
  final Future<void> Function(UserModel) onUpdatePassword;
  final Future<void> Function(UserModel) onToggleDisable;

  const _UsersTab({
    required this.users,
    required this.loading,
    required this.searchQuery,
    required this.roleFilter,
    required this.onSearchChanged,
    required this.onRoleFilterChanged,
    required this.onEditName,
    required this.onUpdatePassword,
    required this.onToggleDisable,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(color: Color(0xFFE6EDF3)),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              hintStyle: const TextStyle(color: Color(0xFF8B949E)),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF8B949E), size: 20),
              filled: true,
              fillColor: const Color(0xFF161B22),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final filter in ['all', 'patient', 'nurse'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onRoleFilterChanged(filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: roleFilter == filter
                            ? const Color(0xFF00BFA5).withOpacity(0.15)
                            : const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: roleFilter == filter
                              ? const Color(0xFF00BFA5)
                              : const Color(0xFF30363D),
                        ),
                      ),
                      child: Text(
                        filter == 'all'
                            ? 'All'
                            : filter[0].toUpperCase() + filter.substring(1),
                        style: TextStyle(
                          color: roleFilter == filter
                              ? const Color(0xFF00BFA5)
                              : const Color(0xFF8B949E),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF00BFA5)))
              : users.isEmpty
                  ? const Center(
                      child: Text('No users found.',
                          style: TextStyle(color: Color(0xFF8B949E))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: users.length,
                      itemBuilder: (ctx, i) => _UserCard(
                        user: users[i],
                        onEditName: onEditName,
                        onUpdatePassword: onUpdatePassword,
                        onToggleDisable: onToggleDisable,
                      ),
                    ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final Future<void> Function(UserModel) onEditName;
  final Future<void> Function(UserModel) onUpdatePassword;
  final Future<void> Function(UserModel) onToggleDisable;

  const _UserCard({
    required this.user,
    required this.onEditName,
    required this.onUpdatePassword,
    required this.onToggleDisable,
  });

  @override
  Widget build(BuildContext context) {
    final isNurse = user.role == UserRole.nurse;
    final roleColor =
        isNurse ? const Color(0xFF58A6FF) : const Color(0xFF3FB950);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isDisabled
              ? const Color(0xFFCF6679).withOpacity(0.3)
              : const Color(0xFF30363D).withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isNurse ? Icons.medical_services_outlined : Icons.person_outline,
              color: roleColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        style: TextStyle(
                          color: user.isDisabled
                              ? const Color(0xFF8B949E)
                              : const Color(0xFFE6EDF3),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: user.isDisabled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isNurse ? 'Nurse' : 'Patient',
                        style: TextStyle(color: roleColor, fontSize: 10),
                      ),
                    ),
                    if (user.isDisabled) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCF6679).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Disabled',
                            style: TextStyle(
                                color: Color(0xFFCF6679), fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(user.email,
                    style: const TextStyle(
                        color: Color(0xFF8B949E), fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF161B22),
            icon: const Icon(Icons.more_vert,
                color: Color(0xFF8B949E), size: 20),
            onSelected: (val) {
              if (val == 'edit') onEditName(user);
              if (val == 'password') onUpdatePassword(user);
              if (val == 'toggle') onToggleDisable(user);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined,
                      size: 16, color: Color(0xFF8B949E)),
                  SizedBox(width: 8),
                  Text('Edit name',
                      style: TextStyle(color: Color(0xFFE6EDF3))),
                ]),
              ),
              const PopupMenuItem(
                value: 'password',
                child: Row(children: [
                  Icon(Icons.lock_reset_outlined,
                      size: 16, color: Color(0xFF8B949E)),
                  SizedBox(width: 8),
                  Text('Reset password',
                      style: TextStyle(color: Color(0xFFE6EDF3))),
                ]),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(
                    user.isDisabled
                        ? Icons.check_circle_outline
                        : Icons.block_outlined,
                    size: 16,
                    color: user.isDisabled
                        ? const Color(0xFF3FB950)
                        : const Color(0xFFCF6679),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user.isDisabled ? 'Enable account' : 'Disable account',
                    style: TextStyle(
                      color: user.isDisabled
                          ? const Color(0xFF3FB950)
                          : const Color(0xFFCF6679),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────
class _StatsTab extends StatelessWidget {
  final int totalPatients;
  final int totalNurses;
  final int totalConversations;
  final int totalRequests;
  final int acceptedRequests;
  final int declinedRequests;
  final int pendingRequests;
  final int endedRequests;
  final int normalRequests;
  final int emergencyRequests;
  final int disabledUsers;
  final int newUsersThisMonth;
  final VoidCallback onRefresh;

  const _StatsTab({
    required this.totalPatients,
    required this.totalNurses,
    required this.totalConversations,
    required this.totalRequests,
    required this.acceptedRequests,
    required this.declinedRequests,
    required this.pendingRequests,
    required this.endedRequests,
    required this.normalRequests,
    required this.emergencyRequests,
    required this.disabledUsers,
    required this.newUsersThisMonth,
    required this.onRefresh,
  });

  List<PieChartSectionData> _buildPieSections() {
    if (totalRequests == 0) {
      return [
        PieChartSectionData(
            value: 1,
            color: const Color(0xFF30363D),
            showTitle: false,
            radius: 28)
      ];
    }
    return [
      if (acceptedRequests > 0)
        PieChartSectionData(
            value: acceptedRequests.toDouble(),
            color: const Color(0xFF3FB950),
            showTitle: false,
            radius: 28),
      if (declinedRequests > 0)
        PieChartSectionData(
            value: declinedRequests.toDouble(),
            color: const Color(0xFFCF6679),
            showTitle: false,
            radius: 28),
      if (pendingRequests > 0)
        PieChartSectionData(
            value: pendingRequests.toDouble(),
            color: const Color(0xFFD29922),
            showTitle: false,
            radius: 28),
      if (endedRequests > 0)
        PieChartSectionData(
            value: endedRequests.toDouble(),
            color: const Color(0xFF8B949E),
            showTitle: false,
            radius: 28),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final activeUsers = (totalPatients + totalNurses) - disabledUsers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Overview',
                  style: TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.refresh,
                    color: Color(0xFF8B949E), size: 20),
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Overview grid ──
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                  label: 'Patients',
                  value: totalPatients,
                  icon: Icons.person_outline,
                  color: const Color(0xFF3FB950)),
              _StatCard(
                  label: 'Nurses',
                  value: totalNurses,
                  icon: Icons.medical_services_outlined,
                  color: const Color(0xFF58A6FF)),
              _StatCard(
                  label: 'Conversations',
                  value: totalConversations,
                  icon: Icons.chat_bubble_outline,
                  color: const Color(0xFF00BFA5)),
              _StatCard(
                  label: 'Call Requests',
                  value: totalRequests,
                  icon: Icons.notifications_outlined,
                  color: const Color(0xFFD29922)),
            ],
          ),
          const SizedBox(height: 24),

          // ── Call Requests Breakdown ──
          const Text('Call Requests Breakdown',
              style: TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF30363D).withOpacity(0.5)),
            ),
            child: totalRequests == 0
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No requests yet',
                          style: TextStyle(color: Color(0xFF8B949E))),
                    ),
                  )
                : Row(
                    children: [
                      SizedBox(
                        height: 130,
                        width: 130,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 38,
                            sections: _buildPieSections(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LegendItem(
                                color: const Color(0xFF3FB950),
                                label: 'Accepted',
                                value: acceptedRequests,
                                total: totalRequests),
                            _LegendItem(
                                color: const Color(0xFFCF6679),
                                label: 'Declined',
                                value: declinedRequests,
                                total: totalRequests),
                            _LegendItem(
                                color: const Color(0xFFD29922),
                                label: 'Pending',
                                value: pendingRequests,
                                total: totalRequests),
                            _LegendItem(
                                color: const Color(0xFF8B949E),
                                label: 'Ended',
                                value: endedRequests,
                                total: totalRequests),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),

          // ── Urgency Breakdown ──
          const Text('Urgency',
              style: TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                    label: 'Normal',
                    value: normalRequests,
                    icon: Icons.notifications_outlined,
                    color: const Color(0xFF3FB950)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                    label: 'Emergency',
                    value: emergencyRequests,
                    icon: Icons.warning_amber_outlined,
                    color: const Color(0xFFCF6679)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── User Accounts ──
          const Text('User Accounts',
              style: TextStyle(
                  color: Color(0xFFE6EDF3),
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                    label: 'Active',
                    value: activeUsers.clamp(0, totalPatients + totalNurses),
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF00BFA5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                    label: 'Disabled',
                    value: disabledUsers,
                    icon: Icons.block_outlined,
                    color: const Color(0xFFCF6679)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                    label: 'New This Month',
                    value: newUsersThisMonth,
                    icon: Icons.person_add_outlined,
                    color: const Color(0xFF58A6FF)),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text('$value',
              style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8B949E), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final int total;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF8B949E), fontSize: 12)),
          ),
          Text('$value',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text('($pct%)',
              style: const TextStyle(
                  color: Color(0xFF8B949E), fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Requests Tab ──────────────────────────────────────────
class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_requests')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child:
                  CircularProgressIndicator(color: Color(0xFF00BFA5)));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text('No requests.',
                  style: TextStyle(color: Color(0xFF8B949E))));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final status = d['status'] as String? ?? 'unknown';
            final Color statusColor;
            switch (status) {
              case 'accepted':
                statusColor = const Color(0xFF3FB950);
                break;
              case 'declined':
                statusColor = const Color(0xFFCF6679);
                break;
              case 'pending':
                statusColor = const Color(0xFFD29922);
                break;
              default:
                statusColor = const Color(0xFF8B949E);
            }
            final ts = d['createdAt'] as Timestamp?;
            final date = ts != null
                ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                : '-';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF30363D).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${d['patientName'] ?? 'Patient'} → ${d['nurseName'] ?? 'Nurse'}',
                          style: const TextStyle(
                              color: Color(0xFFE6EDF3),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d['urgency'] ?? 'normal'} · $date',
                          style: const TextStyle(
                              color: Color(0xFF8B949E), fontSize: 11),
                        ),
                        if (d['declineReason'] != null)
                          Text('Reason: ${d['declineReason']}',
                              style: const TextStyle(
                                  color: Color(0xFFCF6679), fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(status,
                        style:
                            TextStyle(color: statusColor, fontSize: 11)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
