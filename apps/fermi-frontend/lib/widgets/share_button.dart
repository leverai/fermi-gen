import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class ShareButton extends StatefulWidget {
  final VoidCallback onPressed;
  const ShareButton({super.key, required this.onPressed});

  @override
  State<ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<ShareButton> {
  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final foregroundColor = appTheme.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(100),
        highlightColor:
            // ignore: deprecated_member_use
            Colors.grey.withOpacity(0.3),
        splashColor:
            // ignore: deprecated_member_use
            Colors.grey.withOpacity(0.2),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.transparent, // The color is handled by the InkWell
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/share_icon.png',
                color: foregroundColor,
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 5),
              Text(
                'Share',
                style: TextStyle(
                  color: foregroundColor,
                  fontFamily: AppFont.of(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
