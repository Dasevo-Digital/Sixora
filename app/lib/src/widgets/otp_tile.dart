import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';
import '../data/service_icons.dart';
import '../l10n.dart';
import 'common.dart';

/// Colour of an entry's avatar: chosen by the user or derived from the
/// issuer, so the same service always looks the same.
Color avatarColor(OtpEntry e) {
  if (e.color != null) return Color(e.color!);
  final name = e.displayName.toLowerCase();
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.55, 0.45).toColor();
}

const avatarPalette = [
  0xFF1E88E5, 0xFF43A047, 0xFFE53935, 0xFFFB8C00, 0xFF8E24AA, //
  0xFF00897B, 0xFF6D4C41, 0xFF3949AB, 0xFFD81B60, 0xFF546E7A,
];

/// Avatar of an entry: the service's logo on its brand colour, or the first
/// letter of the name.
class EntryAvatar extends StatelessWidget {
  const EntryAvatar(this.entry, {super.key, this.size = 44});
  final OtpEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ServiceIcons?>(
    valueListenable: ServiceIcons.loaded,
    builder: (context, icons, _) {
      final icon = icons?.forEntry(entry);
      if (icon != null) {
        return ServiceIconTile(
          icon: icon,
          size: size,
          color: entry.color == null ? null : Color(entry.color!),
        );
      }
      final name = entry.displayName.trim();
      final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: avatarColor(entry),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.45,
          ),
        ),
      );
    },
  );
}

/// A service logo, white (or black on light colours) on the brand colour.
class ServiceIconTile extends StatelessWidget {
  const ServiceIconTile({
    super.key,
    required this.icon,
    this.size = 44,
    this.color,
  });
  final ServiceIcon icon;
  final double size;

  /// Background instead of the brand colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = color ?? icon.color;
    final light = background.computeLuminance() > 0.6;
    return Tooltip(
      message: icon.title,
      excludeFromSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.3),
          border: light
              ? Border.all(color: Colors.black.withValues(alpha: 0.12))
              : null,
        ),
        padding: EdgeInsets.all(size * 0.2),
        child: CustomPaint(
          painter: _IconPainter(icon, light ? Colors.black : Colors.white),
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);
  final ServiceIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(icon.shape, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color;
}

/// "123 456", "1234 5678", Steam stays in one block.
String groupCode(String code) {
  if (code.length < 6 || RegExp('[A-Z]').hasMatch(code)) return code;
  final half = code.length ~/ 2;
  return '${code.substring(0, half)} ${code.substring(half)}';
}

/// One account in the list: name, current code, countdown.
class OtpTile extends StatefulWidget {
  const OtpTile({
    super.key,
    required this.item,
    required this.ticker,
    required this.onMenu,
    this.vaultName,
  });
  final Item item;
  final Ticker ticker;
  final void Function(Offset? position) onMenu;
  final String? vaultName;

  @override
  State<OtpTile> createState() => _OtpTileState();
}

class _OtpTileState extends State<OtpTile> {
  bool _revealed = false;

  @override
  void didUpdateWidget(OtpTile old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id) _revealed = false;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    final e = widget.item.entry;
    final hidden = c.settings.hideCodes && !_revealed;
    final hotp = e.type == OtpType.hotp;

    return ValueListenableBuilder<DateTime>(
      valueListenable: widget.ticker,
      builder: (context, now, _) {
        String code;
        String? next;
        var remaining = 0;
        var invalid = false;
        try {
          code = e.code(now);
          if (!hotp) {
            remaining = Otp.remaining(now, e.effectivePeriod);
            if (c.settings.showNextCode && remaining <= 5) {
              next = e.code(now.add(Duration(seconds: e.effectivePeriod)));
            }
          }
        } on FormatException {
          code = '––––––';
          invalid = true;
        }
        final urgent = !hotp && remaining <= 5;
        // What a screen reader says: the code digit by digit (otherwise
        // "123456" is read as a number), never a hidden one.
        final spoken = [
          e.displayName,
          if (e.issuer.isNotEmpty && e.account.isNotEmpty) e.account,
          ?widget.vaultName,
          invalid
              ? t.keyInvalidShort
              : hidden
              ? t.codeHidden
              : t.spokenCode(code.split('').join(' ')),
          if (!hotp && !hidden && !invalid) t.secondsLeft(remaining),
        ].join(', ');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            container: true,
            button: !invalid,
            label: spoken,
            onTapHint: hidden ? t.showCode : t.copyCode,
            onLongPressHint: t.moreActions,
            child: InkWell(
              onTap: invalid
                  ? null
                  : () {
                      if (hidden) {
                        setState(() => _revealed = true);
                      } else {
                        copySecret(context, code);
                      }
                    },
              onLongPress: () => widget.onMenu(null),
              onSecondaryTapUp: (d) => widget.onMenu(d.globalPosition),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                child: Row(
                  children: [
                    ExcludeSemantics(child: EntryAvatar(e)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (e.favorite)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Colors.amber.shade600,
                                    ),
                                  ),
                                Flexible(
                                  child: Text(
                                    e.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            if (e.issuer.isNotEmpty && e.account.isNotEmpty ||
                                widget.vaultName != null)
                              Text(
                                [
                                  if (e.issuer.isNotEmpty &&
                                      e.account.isNotEmpty)
                                    e.account,
                                  ?widget.vaultName,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 4),
                            // One line also with large text: a code broken
                            // in the middle is easy to misread.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                hidden ? '••• •••' : groupCode(code),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                  color: urgent && !hidden
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            if (next != null && !hidden)
                              Text(
                                t.nextCodeLabel(groupCode(next)),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (invalid)
                              Text(
                                t.keyIsInvalid,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (hotp)
                      IconButton(
                        tooltip: t.nextCode,
                        icon: const Icon(Icons.refresh),
                        onPressed: () =>
                            runBusy(context, () => c.nextHotp(widget.item)),
                      )
                    else
                      ExcludeSemantics(
                        child: _Countdown(
                          remaining: remaining,
                          period: e.effectivePeriod,
                          urgent: urgent,
                        ),
                      ),
                    IconButton(
                      tooltip: t.more,
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => widget.onMenu(null),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({
    required this.remaining,
    required this.period,
    required this.urgent,
  });
  final int remaining;
  final int period;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = urgent ? scheme.error : scheme.primary;
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: max(0, remaining - 1) / period),
            duration: const Duration(seconds: 1),
            builder: (context, value, _) => CircularProgressIndicator(
              value: value,
              strokeWidth: 3,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          Text(
            '$remaining',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
