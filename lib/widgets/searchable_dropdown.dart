import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class SearchableDropdown extends StatefulWidget {
  final String label;
  final String? value;
  final List<Map<String, String>> items;
  final Function(String?) onChanged;
  final bool enabled;
  final String hintText;

  const SearchableDropdown({
    Key? key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.hintText = 'Search...',
  }) : super(key: key);

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  void _showSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchableDropdownModal(
        label: widget.label,
        currentValue: widget.value,
        items: widget.items,
        onChanged: widget.onChanged,
        hintText: widget.hintText,
      ),
    );
  }

  String? _getSelectedLabel() {
    if (widget.value == null || widget.value!.isEmpty) return null;
    
    try {
      final item = widget.items.firstWhere(
        (item) => item['value'] == widget.value,
        orElse: () => {},
      );
      return item['label'];
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = _getSelectedLabel();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: widget.enabled ? _showSearchModal : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: widget.enabled ? const Color(0xFFF8FAFB) : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedLabel ?? 'Select ${widget.label.replaceAll(' *', '')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: selectedLabel != null 
                          ? const Color(0xFF1A1A1A) 
                          : Colors.grey.shade400,
                      fontWeight: selectedLabel != null ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.search,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchableDropdownModal extends StatefulWidget {
  final String label;
  final String? currentValue;
  final List<Map<String, String>> items;
  final Function(String?) onChanged;
  final String hintText;

  const _SearchableDropdownModal({
    Key? key,
    required this.label,
    required this.currentValue,
    required this.items,
    required this.onChanged,
    required this.hintText,
  }) : super(key: key);

  @override
  State<_SearchableDropdownModal> createState() => _SearchableDropdownModalState();
}

class _SearchableDropdownModalState extends State<_SearchableDropdownModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final label = item['label']?.toLowerCase() ?? '';
          return label.contains(query);
        }).toList();
      }
    });
  }

  void _selectItem(String? value) {
    widget.onChanged(value);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select ${widget.label.replaceAll(' *', '')}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _searchController.text.isNotEmpty 
                      ? AppColors.primaryGreen.withOpacity(0.3)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: _searchController.text.isNotEmpty 
                        ? AppColors.primaryGreen 
                        : Colors.grey[400],
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[400]),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),

          // Results Count
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${_filteredItems.length} result${_filteredItems.length != 1 ? 's' : ''} found',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Items List
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final value = item['value'] ?? '';
                      final label = item['label'] ?? '';
                      final isSelected = value == widget.currentValue;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.primaryGreen.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                                ? AppColors.primaryGreen 
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _selectItem(value),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? AppColors.primaryGreen 
                                  : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(label),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected 
                                  ? AppColors.primaryGreen 
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primaryGreen,
                                  size: 24,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
}