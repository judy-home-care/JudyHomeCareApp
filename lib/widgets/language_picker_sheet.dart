import 'package:flutter/material.dart';

import '../services/i18n/app_language.dart';
import '../services/i18n/t_text.dart';

/// Bottom sheet that lets the user switch the app language.
/// The change applies immediately across the whole app and is persisted.
Future<void> showLanguagePickerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (context) => ValueListenableBuilder<String>(
      valueListenable: AppLanguage.current,
      builder: (context, currentCode, _) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: TText(
                  'Choose Language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: AppLanguage.supported.map((lang) {
                    final selected = lang['code'] == currentCode;
                    return ListTile(
                      leading: Text(
                        lang['flag']!,
                        style: const TextStyle(fontSize: 26),
                      ),
                      title: Text(
                        lang['native']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: TText(
                        lang['name']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF4CAF50))
                          : null,
                      onTap: () async {
                        await AppLanguage.set(lang['code']!);
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    ),
  );
}
