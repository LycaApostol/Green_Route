import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> 
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;
  
  bool _isLoading = false;
  bool _isAdmin = false;
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminStatus();
    _loadStatistics();
  }

  Future<void> _checkAdminStatus() async {
    setState(() => _isLoading = true);
    final isAdmin = await _adminService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
      _isLoading = false;
    });

    if (!isAdmin && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access denied: Admin privileges required'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadStatistics() async {
    final stats = await _adminService.getAppStatistics();
    setState(() => _statistics = stats);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.green[900],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green[900],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.green,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.feedback), text: 'Feedback'),
            Tab(icon: Icon(Icons.notifications), text: 'Alerts'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildFeedbackTab(),
          _buildAlertsTab(),
          _buildUsersTab(),
        ],
      ),
    );
  }

  // DASHBOARD TAB
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Statistics Cards
            _buildStatCard(
              'Total Users',
              _statistics['totalUsers']?.toString() ?? '0',
              Icons.people,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              'Total Feedback',
              _statistics['totalFeedback']?.toString() ?? '0',
              Icons.feedback,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              'Active Alerts',
              _statistics['activeAlerts']?.toString() ?? '0',
              Icons.warning,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FEEDBACK TAB
  Widget _buildFeedbackTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminService.streamAllFeedback(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final feedbackList = snapshot.data ?? [];

        if (feedbackList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.feedback_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No feedback yet', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: feedbackList.length,
          itemBuilder: (context, index) {
            final feedback = feedbackList[index];
            final timestamp = feedback['createdAt'] as Timestamp?;
            final dateStr = timestamp != null 
                ? DateFormat('MMM d, y').format(timestamp.toDate())
                : 'Unknown';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.feedback, color: Colors.orange),
                title: Text(feedback['subject'] ?? 'No subject'),
                subtitle: Text('From: ${feedback['userEmail'] ?? 'Anonymous'} • $dateStr'),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'resolve',
                      child: const Text('Mark as Resolved'),
                      onTap: () => _updateFeedbackStatus(feedback['id'], 'resolved'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      onTap: () => _deleteFeedback(feedback['id']),
                    ),
                  ],
                ),
                onTap: () => _showFeedbackDetails(feedback),
              ),
            );
          },
        );
      },
    );
  }

  void _showFeedbackDetails(Map<String, dynamic> feedback) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feedback['subject'] ?? 'Feedback'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('From: ${feedback['userEmail'] ?? 'Anonymous'}'),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text(feedback['message'] ?? 'No message'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFeedbackStatus(String feedbackId, String status) async {
    final success = await _adminService.updateFeedbackStatus(
      feedbackId: feedbackId,
      status: status,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback updated')),
      );
    }
  }

  Future<void> _deleteFeedback(String feedbackId) async {
    final success = await _adminService.deleteFeedback(feedbackId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback deleted')),
      );
    }
  }

  // ALERTS TAB
  Widget _buildAlertsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: ElevatedButton.icon(
            onPressed: _showCreateAlertDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Alert'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _adminService.streamAllAlerts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final alerts = snapshot.data ?? [];

              if (alerts.isEmpty) {
                return Center(
                  child: Text('No alerts', style: TextStyle(color: Colors.grey[600])),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: alerts.length,
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  final isActive = alert['isActive'] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: isActive ? Colors.amber[50] : Colors.grey[100],
                    child: ListTile(
                      leading: Icon(
                        Icons.notifications,
                        color: isActive ? Colors.amber : Colors.grey,
                      ),
                      title: Text(alert['title'] ?? 'No title'),
                      subtitle: Text(alert['message'] ?? 'No message'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteAlert(alert['id']),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateAlertDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await _adminService.createAlert(
                title: titleController.text,
                message: messageController.text,
                type: 'info',
                priority: 'normal',
              );
              Navigator.pop(ctx);
              if (mounted && result['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alert created')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAlert(String alertId) async {
    final success = await _adminService.deleteAlert(alertId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert deleted')),
      );
    }
  }

  // USERS TAB
  Widget _buildUsersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminService.streamAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return Center(
            child: Text('No users', style: TextStyle(color: Colors.grey[600])),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final isAdmin = user['role'] == 'admin';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAdmin ? Colors.amber[200] : Colors.green[200],
                  child: Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: isAdmin ? Colors.amber[900] : Colors.green[900],
                  ),
                ),
                title: Text(user['name'] ?? 'No name'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['email'] ?? 'No email'),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAdmin ? Colors.amber[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isAdmin ? 'ADMIN' : 'USER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isAdmin ? Colors.amber[900] : Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}