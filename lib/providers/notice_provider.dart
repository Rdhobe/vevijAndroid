import 'package:vevij/components/imports.dart';

class NoticeProvider with ChangeNotifier {
  List<Notice> _notices = [];

  List<Notice> get notices => _notices;

  NoticeProvider() {
    _loadSampleNotices();
  }

  void _loadSampleNotices() {
    _notices = [
      Notice(
        id: '1',
        title: 'Office Closure - National Holiday',
        description: 'The office will be closed on July 15th for Independence Day. All employees are requested to plan their work accordingly.',
        category: 'General',
        postedBy: 'HR Department',
        createdAt: DateTime.now().subtract(Duration(days: 1)),
        additionalInfo: 'Emergency contact numbers will be available for urgent matters.',
      ),
      Notice(
        id: '2',
        title: 'New Safety Protocol Implementation',
        description: 'New safety protocols have been implemented effective immediately. All employees must wear safety helmets in designated areas.',
        category: 'Policy',
        postedBy: 'Safety Manager',
        createdAt: DateTime.now().subtract(Duration(days: 2)),
        additionalInfo: 'Safety training sessions will be conducted next week. Attendance is mandatory.',
      ),
      Notice(
        id: '3',
        title: 'System Maintenance - Server Downtime',
        description: 'The company servers will be down for maintenance from 10 PM to 2 AM tonight. Please save your work and log off before 10 PM.',
        category: 'Urgent',
        postedBy: 'IT Department',
        createdAt: DateTime.now().subtract(Duration(hours: 3)),
        additionalInfo: 'All services will be restored by 2 AM. Contact IT support if you face any issues.',
      ),
      Notice(
        id: '4',
        title: 'Annual Company Picnic',
        description: 'Join us for the annual company picnic on July 25th at Central Park. Food, games, and prizes for everyone!',
        category: 'Event',
        postedBy: 'HR Department',
        createdAt: DateTime.now().subtract(Duration(days: 5)),
        additionalInfo: 'RSVP by July 20th. Family members are welcome. Transportation will be provided.',
      ),
      Notice(
        id: '5',
        title: 'Updated Leave Policy',
        description: 'The company leave policy has been updated. Please review the new guidelines for sick leave and vacation days.',
        category: 'Policy',
        postedBy: 'HR Department',
        createdAt: DateTime.now().subtract(Duration(days: 7)),
        additionalInfo: 'All employees must acknowledge reading the new policy by July 20th.',
      ),
    ];
    notifyListeners();
  }

  void addNotice(Notice notice) {
    _notices.insert(0, notice);
    notifyListeners();
  }

  void updateNotice(String id, Notice updatedNotice) {
    final index = _notices.indexWhere((notice) => notice.id == id);
    if (index != -1) {
      _notices[index] = updatedNotice;
      notifyListeners();
    }
  }

  void deleteNotice(String id) {
    _notices.removeWhere((notice) => notice.id == id);
    notifyListeners();
  }

  Notice? getNoticeById(String id) {
    try {
      return _notices.firstWhere((notice) => notice.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Notice> getNoticesByCategory(String category) {
    return _notices.where((notice) => notice.category == category).toList();
  }

  List<Notice> getRecentNotices({int limit = 5}) {
    final sortedNotices = List<Notice>.from(_notices);
    sortedNotices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedNotices.take(limit).toList();
  }

  List<Notice> searchNotices(String query) {
    if (query.isEmpty) return _notices;
    
    return _notices.where((notice) {
      return notice.title.toLowerCase().contains(query.toLowerCase()) ||
             notice.description.toLowerCase().contains(query.toLowerCase()) ||
             notice.category.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  void markAsRead(String noticeId) {
    // This could be implemented to track read status
    // For now, we'll just notify listeners
    notifyListeners();
  }

  int get totalNotices => _notices.length;
  
  int getNoticeCountByCategory(String category) {
    return _notices.where((notice) => notice.category == category).length;
  }
}