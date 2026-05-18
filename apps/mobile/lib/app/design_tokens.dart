import 'package:flutter/material.dart';

/// PRISM Club mobile design tokens.
///
/// Translated from `design_handoff_prism_club/prototypes/design-system/styles.css`.
/// Pure constants only — no widgets, no theme builders here. Widgets / theme
/// reach into these to stay consistent.
///
/// Pretendard binary bundling is deferred — typography here uses negative
/// letter-spacing + tuned weights to land the hierarchy on the system font.
class PrismSpacing {
  PrismSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double cardPad = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xl2 = 24;
  static const double xl3 = 32;
  static const double xl4 = 40;
  static const double xl5 = 56;
  static const double xl6 = 72;

  static const double screenGutter = 20;
  static const double sectionGap = 24;
}

class PrismRadius {
  PrismRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;
}

/// Club Purple + Ink + Surface + Semantic palette. The legacy aliases at the
/// bottom keep existing call sites compiling while the screens migrate.
class PrismColors {
  PrismColors._();

  // ── Club Purple ramp ──────────────────────────────────────────────────
  static const Color pp50 = Color(0xFFF5F3FF);
  static const Color pp100 = Color(0xFFEDE9FE);
  static const Color pp200 = Color(0xFFDDD6FE);
  static const Color pp300 = Color(0xFFC4B5FD);
  static const Color pp400 = Color(0xFFA78BFA);
  static const Color pp500 = Color(0xFF8B5CF6);
  static const Color pp600 = Color(0xFF7C3AED);
  static const Color pp700 = Color(0xFF6D28D9);
  static const Color pp800 = Color(0xFF5B21B6);
  static const Color pp900 = Color(0xFF4C1D95);

  // ── Ink ramp ──────────────────────────────────────────────────────────
  static const Color ink1 = Color(0xFF0B0B0F);
  static const Color ink2 = Color(0xFF2A2D36);
  static const Color ink3 = Color(0xFF5B5F6B);
  static const Color ink4 = Color(0xFF9097A3);
  static const Color ink5 = Color(0xFFBFC4CC);

  // ── Surface ───────────────────────────────────────────────────────────
  static const Color bg = Color(0xFFFFFFFF);
  static const Color bgSoft = Color(0xFFFAFAFB);
  static const Color bgTint = Color(0xFFF7F6FB);
  static const Color divider = Color(0xFFF2F3F5);
  static const Color line = Color(0xFFECEEF1);
  static const Color line2 = Color(0xFFE2E5EA);

  // ── Semantic ──────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2F9461);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4D6E);
  static const Color info = Color(0xFF3B82F6);
  static const Color gold = Color(0xFFC99536);

  // Paired bg / fg for status pills + role badges (handoff §components).
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successFg = Color(0xFF15803D);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningFg = Color(0xFFB45309);
  static const Color dangerBg = Color(0xFFFFE4E6);
  static const Color dangerFg = Color(0xFFBE123C);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color infoFg = Color(0xFF1D4ED8);
  static const Color neutralBg = Color(0xFFF1F5F9);
  static const Color neutralFg = Color(0xFF475569);

  // ── Legacy aliases (back-compat for existing screens) ─────────────────
  static const Color primary = pp600;
  static const Color text = ink1;
  static const Color muted = ink3;
  static const Color soft = pp100;
  static const Color border = line;
  static const Color background = bg;
  static const Color surface = bgSoft;
}

/// Avatar palette — 10 paired light-bg / dark-fg hue families. Index is
/// stable across runs (djb2 hash of the user's name).
class PrismAvatarPalette {
  PrismAvatarPalette._();

  static const List<({Color bg, Color fg})> pairs = [
    (bg: Color(0xFFEDE9FE), fg: Color(0xFF6D28D9)), // Purple
    (bg: Color(0xFFFCE7F3), fg: Color(0xFFBE185D)), // Pink
    (bg: Color(0xFFFEF3C7), fg: Color(0xFFB45309)), // Amber
    (bg: Color(0xFFDCFCE7), fg: Color(0xFF15803D)), // Green
    (bg: Color(0xFFDBEAFE), fg: Color(0xFF1D4ED8)), // Blue
    (bg: Color(0xFFFFE4E6), fg: Color(0xFFBE123C)), // Rose
    (bg: Color(0xFFF1F5F9), fg: Color(0xFF334155)), // Slate
    (bg: Color(0xFFE0E7FF), fg: Color(0xFF3730A3)), // Indigo
    (bg: Color(0xFFFEF2F2), fg: Color(0xFF991B1B)), // Red
    (bg: Color(0xFFECFDF5), fg: Color(0xFF047857)), // Emerald
  ];

  static ({Color bg, Color fg}) pairFor(String name) {
    if (name.isEmpty) return pairs[0];
    var hash = 5381;
    for (final code in name.codeUnits) {
      hash = ((hash << 5) + hash + code) & 0x7fffffff;
    }
    return pairs[hash % pairs.length];
  }
}

/// Elevation tokens. The default everywhere is flat (1px line border).
/// Shadow is only used for things that actually float (FAB, raised cards,
/// bottom sheets).
class PrismElevation {
  PrismElevation._();

  static const BorderSide flatBorder = BorderSide(color: PrismColors.line);

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x05140926), // rgba(20,14,38,0.02)
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x14140926), // rgba(20,14,38,0.08)
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  static const List<BoxShadow> brand = [
    BoxShadow(
      color: Color(0x666D28D9), // rgba(109,40,217,0.4)
      offset: Offset(0, 12),
      blurRadius: 28,
    ),
  ];

  static const List<BoxShadow> sheet = [
    BoxShadow(
      color: Color(0x2E140926), // rgba(20,14,38,0.18)
      offset: Offset(0, -12),
      blurRadius: 40,
    ),
  ];
}

/// Typography scale tuned to the handoff. Pretendard binary is deferred; we
/// land the hierarchy via weight + size + letter-spacing on the system font.
class PrismType {
  PrismType._();

  static const TextStyle displayLg = TextStyle(
    fontSize: 30,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    color: PrismColors.ink1,
  );

  static const TextStyle titleXl = TextStyle(
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: PrismColors.ink1,
  );

  static const TextStyle titleMd = TextStyle(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: PrismColors.ink1,
  );

  static const TextStyle titleSm = TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: PrismColors.ink1,
  );

  // Body / caption / label keep letter-spacing near 0 — Korean glyph
  // rendering reads worse than Latin under negative tracking. Negative
  // letter-spacing is reserved for display / title sizes.
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    height: 1.55,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: PrismColors.ink1,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: PrismColors.ink2,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: PrismColors.ink2,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: PrismColors.ink3,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: PrismColors.pp700,
  );

  static const TextStyle numeric = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
    color: PrismColors.ink1,
  );
}
