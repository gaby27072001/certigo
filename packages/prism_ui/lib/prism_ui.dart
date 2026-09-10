/// Prism — the Certigo design system.
///
/// A premium, Liquid-Glass-inspired UI kit: translucent surfaces, luminous
/// depth and motivating progress components, implemented with cross-platform
/// Flutter techniques (backdrop blur, gradients, custom paint).
///
/// Import this single barrel to access tokens, theme and components:
/// ```dart
/// import 'package:prism_ui/prism_ui.dart';
/// ```
library prism_ui;

// Tokens
export 'src/tokens/prism_colors.dart';
export 'src/tokens/prism_spacing.dart';
export 'src/tokens/prism_radii.dart';
export 'src/tokens/prism_elevation.dart';
export 'src/tokens/prism_layout.dart';
export 'src/tokens/prism_motion.dart';
export 'src/tokens/prism_state.dart';
export 'src/tokens/prism_typography.dart';
export 'src/tokens/prism_brand_icons.dart';

// Theme
export 'src/theme/prism_color_scheme.dart';
export 'src/theme/prism_theme.dart';

// Components
export 'src/components/glass_surface.dart';
export 'src/components/prism_card.dart';
export 'src/components/prism_pressable.dart';
export 'src/components/prism_content_frame.dart';
export 'src/components/prism_section_header.dart';
export 'src/components/prism_reveal.dart';
export 'src/components/prism_page_transition.dart';
export 'src/components/aurora_background.dart';
export 'src/components/orbit_field.dart';
export 'src/components/gradient_text.dart';
export 'src/components/prism_button.dart';
export 'src/components/prism_progress_bar.dart';
export 'src/components/readiness_gauge.dart';
export 'src/components/stat_pill.dart';
export 'src/components/streak_badge.dart';
export 'src/components/xp_chip.dart';
export 'src/components/gem_counter.dart';
export 'src/components/lesson_tile.dart';

// Certification catalogue (vendor → certification → chapter)
export 'src/components/vendor_brand.dart';
export 'src/components/vendor_tile.dart';
export 'src/components/certification_card.dart';
export 'src/components/chapter_section_card.dart';
export 'src/components/quiz_option_tile.dart';
export 'src/components/answer_chip.dart';
export 'src/components/match_tile.dart';

// Skill-path & Aurora Crew
export 'src/components/aurora_mascot.dart';
export 'src/components/mascot_assets.dart';
export 'src/components/path_node.dart';
export 'src/components/unit_header.dart';

// Onboarding / playful "Duo kit"
export 'src/components/speech_bubble.dart';
export 'src/components/choice_tile.dart';
export 'src/components/onboarding_scaffold.dart';
export 'src/components/typewriter_text.dart';
export 'src/components/recommended_option_card.dart';
export 'src/components/signal_bars.dart';

// Pedagogical blocks (Lesson Engine)
export 'src/components/hook_block.dart';
export 'src/components/concept_block.dart';
export 'src/components/scenario_block.dart';
export 'src/components/code_block.dart';
export 'src/components/key_takeaway_block.dart';
export 'src/components/callout_block.dart';
export 'src/components/answer_feedback_card.dart';
export 'src/components/prism_rich_text.dart';

// Async / state surfaces
export 'src/components/prism_skeleton.dart';
export 'src/components/prism_status_view.dart';
export 'src/components/prism_loading_view.dart';

// Dynamic content rendering (ADR-003)
export 'src/rendering/content_block.dart';
export 'src/rendering/block_fallback.dart';
export 'src/rendering/renderer_registry.dart';
export 'src/rendering/standard_renderers.dart';
export 'src/rendering/content_schema.dart';
