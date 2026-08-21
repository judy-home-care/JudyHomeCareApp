import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';
import '../../services/dashboard/dashboard_service.dart';
import '../../services/app_version_service.dart';
import '../../services/notification_service.dart';
import '../../services/patients/nurse_patient_service.dart';
import '../../models/dashboard/therapist_dashboard_models.dart';
import '../modern_notifications_sheet.dart';

/// Dashboard for physiotherapists and speech therapists.
///
/// Shows: greeting + discipline badge, quick stats (assigned patients,
/// sessions today, notes this week, total notes), a weekly activity strip,
/// quick actions, patients needing attention (no session in 7+ days),
/// "My patients" and the most recent session notes.
class TherapistDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> therapistData;
  final Function(int)? onTabChange;

  const TherapistDashboardScreen({
    Key? key,
    required this.therapistData,
    this.onTabChange,
  }) : super(key: key);

  @override
  State<TherapistDashboardScreen> createState() => _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _dashboardService = DashboardService();
  final _notificationService = NotificationService();

  TherapistDashboardData? _data;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  DateTime? _lastFetchTime;
  bool _isTabVisible = false;
  Timer? _visibilityDebounce;
  int _unreadNotificationCount = 0;
  VoidCallback? _removeCountListener;
  VoidCallback? _removeReceivedListener;

  // Set when a push arrives while the app/tab is not in the foreground so we
  // refresh as soon as it becomes visible again.
  bool _pendingNotificationRefresh = false;

  static const Duration _cacheValidity = Duration(minutes: 2);

  @override
  bool get wantKeepAlive => true;

  String get _role => (widget.therapistData['role'] ?? 'physiotherapist').toString();
  bool get _isSpeech => _role == 'speech_therapist';
  String get _roleLabel => _isSpeech ? 'Speech Therapist' : 'Physiotherapist';
  String get _therapyLabel => _isSpeech ? 'Speech Therapy' : 'Physiotherapy';
  Color get _accent => _isSpeech ? const Color(0xFFB45309) : const Color(0xFF0284C7);
  Color get _accentBg => _isSpeech ? const Color(0xFFFFF4E5) : const Color(0xFFE0F2FE);
  IconData get _roleIcon => _isSpeech ? Icons.record_voice_over_outlined : Icons.accessibility_new_rounded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadDashboard();
    _loadUnreadNotificationCount();
    _removeCountListener = _notificationService.addNotificationCountListener((count) {
      if (mounted) setState(() => _unreadNotificationCount = count);
    });

    // A note saved from the Patients tab should be reflected here (Sessions
    // Today / Notes This Week / Total Notes / Recent notes) without a manual
    // pull-to-refresh.
    NursePatientService.therapyNotesChanged.addListener(_onTherapyNotesChanged);

    // Real-time updates: any push (e.g. a patient assigned / unassigned to
    // this therapist, a new note) triggers a silent dashboard refresh.
    _removeReceivedListener = _notificationService.addNotificationReceivedListener(() {
      if (!mounted) return;
      if (_isTabVisible) {
        debugPrint('🔄 [TherapistDashboard] Push received - refreshing dashboard');
        loadDashboard(forceRefresh: true, silent: true);
      } else {
        _pendingNotificationRefresh = true;
      }
    });
  }

  void _onTherapyNotesChanged() {
    if (!mounted) return;
    if (_isTabVisible) {
      loadDashboard(forceRefresh: true, silent: true);
    } else {
      // Refresh as soon as the user comes back to the dashboard tab
      _pendingNotificationRefresh = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visibilityDebounce?.cancel();
    _removeCountListener?.call();
    _removeReceivedListener?.call();
    NursePatientService.therapyNotesChanged.removeListener(_onTherapyNotesChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isTabVisible) {
      _consumePendingRefreshOrRefreshIfStale();
    }
  }

  // Called by TherapistMainScreen
  void onTabVisible() {
    _isTabVisible = true;
    _visibilityDebounce?.cancel();
    _visibilityDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || !_isTabVisible) return;
      _consumePendingRefreshOrRefreshIfStale();
      _loadUnreadNotificationCount();
    });
  }

  /// If a push arrived while we were hidden/backgrounded (or the user tapped a
  /// notification), force a refresh; otherwise refresh only if the cache is stale.
  void _consumePendingRefreshOrRefreshIfStale() {
    final tappedWhileBackground = _notificationService.hasNotificationWhileBackground;
    if (_pendingNotificationRefresh || tappedWhileBackground) {
      _pendingNotificationRefresh = false;
      _notificationService.clearBackgroundNotificationFlag();
      loadDashboard(forceRefresh: true, silent: true);
      return;
    }
    _refreshIfStale();
  }

  void onTabHidden() {
    _isTabVisible = false;
    _visibilityDebounce?.cancel();
  }

  void _refreshIfStale() {
    if (_lastFetchTime == null ||
        DateTime.now().difference(_lastFetchTime!) > _cacheValidity) {
      loadDashboard(forceRefresh: true, silent: true);
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final response = await _notificationService.getUnreadCount();
      if (mounted) setState(() => _unreadNotificationCount = response.unreadCount);
    } catch (_) {}
  }

  Future<void> loadDashboard({bool forceRefresh = false, bool silent = false}) async {
    if (_isRefreshing) return;
    if (!forceRefresh && _data != null && _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidity) {
      return;
    }

    _isRefreshing = true;
    if (!silent && mounted) {
      setState(() {
        _isLoading = _data == null;
        _error = null;
      });
    }

    try {
      final response = await _dashboardService.getTherapistMobileDashboard();
      if (!mounted) return;
      setState(() {
        _data = response.data;
        _lastFetchTime = DateTime.now();
        _isLoading = false;
        _error = null;
      });

      if (response.versionRequirement != null) {
        final versionService = AppVersionService();
        if (versionService.needsUpdate(response.versionRequirement!)) {
          versionService.showForceUpdateDialog(context, requirement: response.versionRequirement);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_data == null) _error = 'Could not load your dashboard. Pull down to retry.';
      });
    } finally {
      _isRefreshing = false;
    }
  }

  void _openNotifications() {
    showNotificationsSheet(context).then((_) => _loadUnreadNotificationCount());
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () => loadDashboard(forceRefresh: true),
          child: _isLoading
              ? _buildLoading()
              : _error != null && _data == null
                  ? _buildError()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      children: const [
        SizedBox(height: 200),
        Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          _error ?? 'Something went wrong',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: () => loadDashboard(forceRefresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final data = _data!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _buildGreeting(data),
        const SizedBox(height: 20),
        _buildStats(data.stats),
        const SizedBox(height: 20),
        _buildWeeklyActivity(data.weeklyActivity, data.stats),
        const SizedBox(height: 24),
        _buildQuickActions(),
        if (data.needsAttention.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildNeedsAttention(data.needsAttention),
        ],
        const SizedBox(height: 28),
        _buildMyPatients(data.patients),
        const SizedBox(height: 28),
        _buildRecentNotes(data.recentNotes),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  Widget _buildGreeting(TherapistDashboardData data) {
    final firstName = (widget.therapistData['name'] ?? data.therapist.name)
        .toString()
        .split(' ')
        .first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accentBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_roleIcon, size: 14, color: _accent),
                        const SizedBox(width: 5),
                        Text(
                          data.therapist.roleLabel.isNotEmpty ? data.therapist.roleLabel : _roleLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _accent),
                        ),
                      ],
                    ),
                  ),
                  if (data.therapist.staffId != null && data.therapist.staffId!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      data.therapist.staffId!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
              if (data.today != null) ...[
                const SizedBox(height: 6),
                Text(
                  data.today!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
        GestureDetector(
          onTap: _openNotifications,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_outlined, color: Color(0xFF1A1A1A)),
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFFF4757), shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(TherapistDashboardStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.people_outline,
                label: 'My Patients',
                value: '${stats.assignedPatients}',
                iconColor: const Color(0xFF199A8E),
                bgColor: const Color(0xFFE8F5F5),
                onTap: () => widget.onTabChange?.call(1),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.today_outlined,
                label: 'Sessions Today',
                value: '${stats.sessionsToday}',
                iconColor: const Color(0xFFFF6B6B),
                bgColor: const Color(0xFFFFE5E5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.edit_note_rounded,
                label: 'Notes This Week',
                value: '${stats.notesThisWeek}',
                iconColor: const Color(0xFF6C63FF),
                bgColor: const Color(0xFFEDE9FF),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.library_books_outlined,
                label: 'Total Notes',
                value: '${stats.totalNotes}',
                iconColor: const Color(0xFFFF9A00),
                bgColor: const Color(0xFFFFF3E0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    final isSmall = MediaQuery.of(context).size.height < 700;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmall ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmall ? 8 : 10),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, size: isSmall ? 18 : 20, color: iconColor),
            ),
            SizedBox(width: isSmall ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: isSmall ? 11 : 12, color: Colors.grey.shade600, letterSpacing: -0.2),
                  ),
                  SizedBox(height: isSmall ? 1 : 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isSmall ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyActivity(List<TherapistWeeklyActivityDay> days, TherapistDashboardStats stats) {
    if (days.isEmpty) return const SizedBox.shrink();
    final maxCount = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'This week',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              ),
              const Spacer(),
              Text(
                '${stats.patientsSeenThisWeek} patient${stats.patientsSeenThisWeek == 1 ? '' : 's'} seen',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            // count label (14) + gap (3) + max bar (50) + gap (6) + day label (16)
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((d) {
                final ratio = maxCount == 0 ? 0.0 : d.count / maxCount;
                final barHeight = 8 + (42 * ratio);
                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Always reserve the label row so bars share a baseline
                      SizedBox(
                        height: 14,
                        child: d.count > 0
                            ? Text('${d.count}', style: TextStyle(fontSize: 10, height: 1.2, color: Colors.grey.shade700, fontWeight: FontWeight.w600))
                            : null,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: barHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: d.isToday
                              ? _accent
                              : (d.count > 0 ? _accent.withOpacity(0.45) : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.dayLabel,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: d.isToday ? FontWeight.w700 : FontWeight.w500,
                          color: d.isToday ? _accent : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.edit_note_rounded,
                title: 'New Session Note',
                subtitle: 'Pick a patient and write your ${_therapyLabel.toLowerCase()} note',
                color: _accent,
                bg: _accentBg,
                onTap: () => widget.onTabChange?.call(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.people_alt_outlined,
                title: 'My Patients',
                subtitle: 'Details, vitals, care plan & history',
                color: AppColors.primaryGreen,
                bg: const Color(0xFFE8F5F5),
                onTap: () => widget.onTabChange?.call(1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedsAttention(List<TherapistDashboardPatient> patients) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notification_important_outlined, size: 20, color: Color(0xFFFF9A00)),
            const SizedBox(width: 8),
            const Text(
              'Due for a session',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'No session recorded in the last 7 days',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: patients.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = patients[i];
              return GestureDetector(
                onTap: () => widget.onTabChange?.call(1),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFF9A00).withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildAvatar(p.avatar, p.name, 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        p.daysSinceLastSession == null
                            ? 'No sessions yet'
                            : 'Last session ${p.daysSinceLastSession} day${p.daysSinceLastSession == 1 ? '' : 's'} ago',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.careType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyPatients(List<TherapistDashboardPatient> patients) {
    final shown = patients.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My patients',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
            ),
            TextButton(
              onPressed: () => widget.onTabChange?.call(1),
              child: Row(
                children: [
                  Text('See all', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, letterSpacing: -0.2)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade600),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          _buildEmptyCard(
            icon: Icons.person_search_outlined,
            title: 'No patients assigned yet',
            subtitle: 'Patients assigned to you by the care team will appear here.',
          )
        else
          ...shown.map(_buildPatientCard),
      ],
    );
  }

  Widget _buildPatientCard(TherapistDashboardPatient p) {
    final priorityColor = _priorityColor(p.priority);
    return GestureDetector(
      onTap: () => widget.onTabChange?.call(1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(p.avatar, p.name, 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), letterSpacing: -0.3),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          p.priority.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: priorityColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.age != null ? '${p.age} yrs • ' : ''}${p.careType}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.history, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        'Last session: ${p.lastSessionDisplay}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        '${p.sessionsCount} note${p.sessionsCount == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w600),
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

  Widget _buildRecentNotes(List<TherapistDashboardNote> notes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent session notes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),
        if (notes.isEmpty)
          _buildEmptyCard(
            icon: Icons.edit_note_rounded,
            title: 'No notes yet',
            subtitle: 'Open a patient and use the Daily Notes tab to record your first $_therapyLabel note.',
          )
        else
          ...notes.map(_buildNoteCard),
      ],
    );
  }

  Widget _buildNoteCard(TherapistDashboardNote n) {
    String when = n.sessionDateDisplay ?? '';
    if (n.sessionTime != null && n.sessionTime!.contains(':')) {
      try {
        final parts = n.sessionTime!.split(':');
        final t = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
        when = '$when • ${DateFormat('h:mm a').format(t)}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: _accent, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  n.patientName ?? 'Patient',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                ),
              ),
              Text(when, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _accentBg, borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${n.therapyTypeLabel} Note',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            n.excerpt,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF333333)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Small helpers
  // ---------------------------------------------------------------------------

  Widget _buildAvatar(String? url, String name, double size) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
        ),
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _buildEmptyCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
        ],
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFFF4757);
      case 'medium':
        return const Color(0xFFFF9A00);
      case 'low':
        return const Color(0xFF199A8E);
      default:
        return Colors.grey;
    }
  }
}
