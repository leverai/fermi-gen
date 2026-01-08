import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/avatar_widget.dart';

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({
    super.key,
    required this.apiService,
    this.currentDisplayName,
    this.currentAvatarUrl,
    required this.onSave,
  });

  final ApiService apiService;
  final String? currentDisplayName;
  final String? currentAvatarUrl;
  final Function(String? displayName, String? avatarUrl) onSave;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final TextEditingController _nameController;
  List<String> _avatars = [];
  String? _selectedAvatarUrl;
  bool _isLoadingAvatars = true;
  bool _isSaving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentDisplayName);
    _selectedAvatarUrl = widget.currentAvatarUrl;
    _loadAvatars();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatars() async {
    try {
      final avatars = await widget.apiService.getAvatars();
      if (mounted) {
        setState(() {
          _avatars = avatars;
          _isLoadingAvatars = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAvatars = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load avatars: $e')),
        );
      }
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Empty is allowed
    }

    final trimmed = value.trim();

    // Length validation
    if (trimmed.length < 3) {
      return 'Name must be at least 3 characters';
    }
    if (trimmed.length > 30) {
      return 'Name must be at most 30 characters';
    }

    // Allow alphanumeric, spaces, and common special characters
    final validPattern = RegExp(r'^[a-zA-Z0-9\s._\-]+$');
    if (!validPattern.hasMatch(trimmed)) {
      return 'Name can only contain letters, numbers, spaces, and ._-';
    }

    return null;
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final error = _validateName(name);

    if (error != null) {
      setState(() => _nameError = error);
      return;
    }

    setState(() {
      _isSaving = true;
      _nameError = null;
    });

    try {
      await widget.apiService.updateUserProfile(
        displayName: name.isNotEmpty ? name : null,
        avatarUrl: _selectedAvatarUrl,
      );
      widget.onSave(name.isNotEmpty ? name : null, _selectedAvatarUrl);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: appTheme.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: appTheme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appTheme.borderMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _isSaving
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : TextButton(
                        onPressed: _handleSave,
                        child: Text(
                          'Save',
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: appTheme.primary,
                          ),
                        ),
                      ),
                Text(
                  'Edit profile',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: appTheme.text,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_down,
                      color: appTheme.border, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                crossAxisAlignmentLabel('Display name', appTheme, context),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: appTheme.text),
                  onChanged: (value) {
                    // Clear error when user types
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: appTheme.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _nameError != null
                            ? appTheme.danger
                            : appTheme.borderMuted,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _nameError != null
                            ? appTheme.danger
                            : appTheme.borderMuted,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _nameError != null
                            ? appTheme.danger
                            : appTheme.primary,
                      ),
                    ),
                    errorText: _nameError,
                    errorStyle: TextStyle(color: appTheme.danger),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                Divider(color: appTheme.borderMuted, thickness: 1),
                const SizedBox(height: 24),

                if (_isLoadingAvatars)
                  const Center(child: CircularProgressIndicator())
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _avatars.length,
                    itemBuilder: (context, index) {
                      final url = _avatars[index];
                      final isSelected = _selectedAvatarUrl == url;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAvatarUrl = url),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                AvatarWidget(
                                  imageUrl: url,
                                  size: constraints.maxWidth,
                                  borderColor: isSelected
                                      ? appTheme.primary
                                      : Colors.transparent,
                                  borderWidth: 2.0,
                                  padding: const EdgeInsets.all(4.0),
                                  placeholder: CircularProgressIndicator(
                                    color: appTheme.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: appTheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: appTheme.bgLight,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 12,
                                        color: appTheme.bgLight,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
                // Extra space at bottom
                SizedBox(height: 48 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget crossAxisAlignmentLabel(
      String text, AppTheme appTheme, BuildContext context) {
    return Text(
      text,
      style: AppFont.primaryTextStyle(
        context,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: appTheme.textMuted,
      ),
    );
  }
}
