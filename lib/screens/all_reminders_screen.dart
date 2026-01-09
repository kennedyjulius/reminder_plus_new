import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../models/reminder_model.dart';
import '../services/reminder_service.dart';
import '../widgets/reminder_card.dart';

class AllRemindersScreen extends StatefulWidget {
  const AllRemindersScreen({super.key});

  @override
  State<AllRemindersScreen> createState() => _AllRemindersScreenState();
}

class _AllRemindersScreenState extends State<AllRemindersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Pending, Completed
  String _selectedSort = 'Date'; // Date, Title, Created

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'All Reminders',
          style: GoogleFonts.roboto(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.primaryText),
            tooltip: 'Missed Reminders',
            onPressed: () {
              Navigator.pushNamed(context, '/missed-reminders');
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppColors.primaryText),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              style: GoogleFonts.roboto(color: AppColors.primaryText),
              decoration: InputDecoration(
                hintText: 'Search reminders by title or date...',
                hintStyle: GoogleFonts.roboto(color: AppColors.secondaryText),
                prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.secondaryText),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),

          // Filter Chips
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('All', _selectedFilter == 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', _selectedFilter == 'Pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', _selectedFilter == 'Completed'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Reminders List
          Expanded(
            child: StreamBuilder<List<ReminderModel>>(
              stream: ReminderService.getAllUserReminders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: AppColors.secondaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reminders found',
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first reminder to get started',
                          style: GoogleFonts.roboto(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter and search reminders
                List<ReminderModel> filteredReminders = _filterAndSearchReminders(snapshot.data!);

                if (filteredReminders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppColors.secondaryText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reminders match your search',
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: GoogleFonts.roboto(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = filteredReminders[index];
                    
                    final now = DateTime.now();
                    final reminderDate = reminder.dateTime;
                    final months = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    final dateString = (reminderDate.year == now.year &&
                            reminderDate.month == now.month &&
                            reminderDate.day == now.day)
                        ? 'Today'
                        : '${months[reminderDate.month - 1]} ${reminderDate.day}, ${reminderDate.year}';
                    
                    final hour = reminder.dateTime.hour;
                    final minute = reminder.dateTime.minute;
                    final period = hour >= 12 ? 'PM' : 'AM';
                    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                    final timeString = '$displayHour:${minute.toString().padLeft(2, '0')} $period';

                    return Padding(
                      padding: EdgeInsets.only(bottom: index < filteredReminders.length - 1 ? 12 : 0),
                      child: ReminderCard(
                        title: reminder.title,
                        date: dateString,
                        time: timeString,
                        isCompleted: reminder.isCompleted,
                        onTap: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            '/reminder-details',
                            arguments: {'reminderId': reminder.id},
                          );
                          // Refresh if reminder was deleted
                          if (result == true) {
                            setState(() {});
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.confirmButton : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.confirmButton : AppColors.inputBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.roboto(
            color: isSelected ? AppColors.primaryText : AppColors.secondaryText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  List<ReminderModel> _filterAndSearchReminders(List<ReminderModel> reminders) {
    List<ReminderModel> filtered = reminders;

    // Apply status filter
    switch (_selectedFilter) {
      case 'Pending':
        filtered = filtered.where((r) => !r.isCompleted).toList();
        break;
      case 'Completed':
        filtered = filtered.where((r) => r.isCompleted).toList();
        break;
      case 'All':
      default:
        // No additional filtering needed
        break;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((reminder) {
        final title = reminder.title.toLowerCase();
        final dateStr = '${reminder.dateTime.day}/${reminder.dateTime.month}/${reminder.dateTime.year}';
        
        return title.contains(_searchQuery) || 
               dateStr.contains(_searchQuery) ||
               reminder.source.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Apply sorting
    switch (_selectedSort) {
      case 'Title':
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Created':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Date':
      default:
        filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        break;
    }

    return filtered;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Sort & Filter',
          style: GoogleFonts.roboto(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sort Options
            Text(
              'Sort by:',
              style: GoogleFonts.roboto(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...['Date', 'Title', 'Created'].map((sort) {
              return RadioListTile<String>(
                title: Text(
                  sort,
                  style: GoogleFonts.roboto(color: AppColors.primaryText),
                ),
                value: sort,
                groupValue: _selectedSort,
                activeColor: AppColors.confirmButton,
                onChanged: (value) {
                  setState(() {
                    _selectedSort = value!;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.roboto(color: AppColors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

