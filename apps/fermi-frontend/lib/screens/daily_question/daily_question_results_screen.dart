// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:fermi_frontend/services/daily_question_service.dart';
// import 'package:fermi_frontend/controllers/daily_question_controller.dart';
// import 'package:fermi_frontend/theme/app_theme.dart';
// import 'package:fermi_frontend/theme/app_font.dart';
// import 'package:fermi_frontend/widgets/question_widget.dart';
// import 'package:fermi_frontend/widgets/slider_text_mirror.dart';

// /// Screen to display results for a past/closed daily question.
// class DailyQuestionResultsScreen extends StatefulWidget {
//   final String questionDate; // YYYY-MM-DD format

//   const DailyQuestionResultsScreen({
//     super.key,
//     required this.questionDate,
//   });

//   @override
//   State<DailyQuestionResultsScreen> createState() =>
//       _DailyQuestionResultsScreenState();
// }

// class _DailyQuestionResultsScreenState
//     extends State<DailyQuestionResultsScreen> {
//   DQResultsResponse? _results;
//   bool _isLoading = true;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _loadResults();
//     // Mark this date's results as seen
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) {
//         context
//             .read<DailyQuestionController>()
//             .markResultsSeen(widget.questionDate);
//       }
//     });
//   }

//   String _getFriendlyErrorMessage(String error) {
//     final errorLower = error.toLowerCase();
//     if (errorLower.contains('results are not yet available') ||
//         errorLower.contains('not yet available') ||
//         errorLower.contains('409')) {
//       return 'Results are pending. Please check back later after the question window closes.';
//     }
//     if (errorLower.contains('no daily question found') ||
//         errorLower.contains('not found') ||
//         errorLower.contains('404')) {
//       return 'No daily question found for this date.';
//     }
//     // Return a cleaned version of the error message
//     if (error.length > 150) {
//       return '${error.substring(0, 150)}...';
//     }
//     return error;
//   }

//   Future<void> _loadResults() async {
//     try {
//       print('[DQResultsScreen] Loading results for ${widget.questionDate}');
//       final service = context.read<DailyQuestionService>();
//       print('[DQResultsScreen] Got service, calling getResultsForDate...');
//       final results = await service.getResultsForDate(widget.questionDate);
//       print('[DQResultsScreen] Got results: ${results.questionText}');
//       if (mounted) {
//         setState(() {
//           _results = results;
//           _isLoading = false;
//         });
//       }
//     } catch (e, st) {
//       print('[DQResultsScreen] Error: $e');
//       print('[DQResultsScreen] Stack: $st');
//       if (mounted) {
//         setState(() {
//           _error = _getFriendlyErrorMessage(e.toString());
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appTheme =
//         Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

//     if (_isLoading) {
//       return Scaffold(
//         backgroundColor: appTheme.bg,
//         appBar: AppBar(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           leading: IconButton(
//             icon: Icon(Icons.close, color: appTheme.text),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           title: Text(
//             'Results',
//             style: AppFont.primaryTextStyle(
//               context,
//               color: appTheme.text,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           centerTitle: true,
//         ),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }

//     if (_error != null) {
//       return Scaffold(
//         backgroundColor: appTheme.bg,
//         appBar: AppBar(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           leading: IconButton(
//             icon: Icon(Icons.close, color: appTheme.text),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           title: Text(
//             'Results',
//             style: AppFont.primaryTextStyle(
//               context,
//               color: appTheme.text,
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           centerTitle: true,
//         ),
//         body: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(
//                   _error!.toLowerCase().contains('pending')
//                       ? Icons.schedule
//                       : Icons.error_outline,
//                   size: 64,
//                   color: _error!.toLowerCase().contains('pending')
//                       ? appTheme.primary
//                       : appTheme.danger,
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   _error!.toLowerCase().contains('pending')
//                       ? 'Results Pending'
//                       : 'Could not load results',
//                   style: AppFont.primaryTextStyle(
//                     context,
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                     color: appTheme.text,
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   _error!,
//                   style: AppFont.secondaryTextStyle(
//                     context,
//                     color: appTheme.textMuted,
//                   ),
//                   textAlign: TextAlign.center,
//                   maxLines: 5,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     final results = _results!;

//     return Scaffold(
//       backgroundColor: appTheme.bg,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: Icon(Icons.close, color: appTheme.text),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         title: Text(
//           'Results - ${results.questionDate}',
//           style: AppFont.primaryTextStyle(
//             context,
//             color: appTheme.text,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//         centerTitle: true,
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // Question
//               QuestionWidget(
//                 text: results.questionText,
//                 tags: const [],
//                 height: 150,
//               ),
//               const SizedBox(height: 24),

//               // Correct Answer Section
//               _buildSection(
//                 appTheme,
//                 'Correct Answer',
//                 child: SliderTextMirror(value: results.correctAnswer),
//               ),
//               const SizedBox(height: 16),

//               // User's Answer (if participated)
//               if (results.userAnswer != null) ...[
//                 _buildSection(
//                   appTheme,
//                   'Your Answer',
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       SliderTextMirror(value: results.userAnswer!),
//                       const SizedBox(height: 8),
//                       if (results.userScore != null)
//                         Text(
//                           'Score: ${results.userScore!.toStringAsFixed(0)}',
//                           style: AppFont.primaryTextStyle(
//                             context,
//                             fontSize: 18,
//                             fontWeight: FontWeight.w700,
//                             color: appTheme.primary,
//                           ),
//                         ),
//                       if (results.userRank != null)
//                         Text(
//                           'Rank: #${results.userRank} of ${results.totalParticipants}',
//                           style: AppFont.secondaryTextStyle(
//                             context,
//                             color: appTheme.textMuted,
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//               ] else ...[
//                 _buildSection(
//                   appTheme,
//                   'Your Result',
//                   child: Text(
//                     'You did not participate in this question.',
//                     style: AppFont.secondaryTextStyle(
//                       context,
//                       color: appTheme.textMuted,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//               ],

//               // Leaderboard
//               _buildSection(
//                 appTheme,
//                 'Leaderboard (${results.totalParticipants} participants)',
//                 child: results.leaderboard.isEmpty
//                     ? Text(
//                         'No participants yet.',
//                         style: AppFont.secondaryTextStyle(
//                           context,
//                           color: appTheme.textMuted,
//                         ),
//                       )
//                     : Column(
//                         children: results.leaderboard.map((entry) {
//                           return Padding(
//                             padding: const EdgeInsets.symmetric(vertical: 4),
//                             child: Row(
//                               children: [
//                                 SizedBox(
//                                   width: 32,
//                                   child: Text(
//                                     '#${entry.rank}',
//                                     style: AppFont.secondaryTextStyle(
//                                       context,
//                                       fontWeight: FontWeight.w700,
//                                       color: appTheme.text,
//                                     ),
//                                   ),
//                                 ),
//                                 Expanded(
//                                   child: Text(
//                                     entry.displayName ?? 'Anonymous',
//                                     style: AppFont.secondaryTextStyle(
//                                       context,
//                                       color: appTheme.text,
//                                     ),
//                                   ),
//                                 ),
//                                 Text(
//                                   '${entry.score.toStringAsFixed(0)} pts',
//                                   style: AppFont.secondaryTextStyle(
//                                     context,
//                                     fontWeight: FontWeight.w600,
//                                     color: appTheme.primary,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           );
//                         }).toList(),
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSection(AppTheme appTheme, String title,
//       {required Widget child}) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: appTheme.bgLight,
//         borderRadius: BorderRadius.circular(appTheme.borderRadius),
//         border: Border.all(
//           color: appTheme.border,
//           width: appTheme.borderWidth,
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: AppFont.secondaryTextStyle(
//               context,
//               fontSize: 12,
//               fontWeight: FontWeight.w700,
//               color: appTheme.textMuted,
//             ),
//           ),
//           const SizedBox(height: 8),
//           child,
//         ],
//       ),
//     );
//   }
// }
