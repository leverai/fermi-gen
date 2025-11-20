import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/services/game_realtime.dart';

/// Factory functions and sample data for questions in tests.
///
/// Provides reusable question payloads with text, tags, units, correct
/// answers, and example percentiles. All data is pure Dart with no
/// external dependencies.
class QuestionDataFixtures {
  /// Sample question texts for different categories.
  static const String sampleQuestion1 =
      'How many people live in New York City?';
  static const String sampleQuestion2 =
      'What is the mass of the Earth in kilograms?';
  static const String sampleQuestion3 =
      'How many seconds are in a year?';
  static const String sampleQuestion4 =
      'What is the speed of light in meters per second?';
  static const String sampleQuestion5 =
      'How many atoms are in a mole of carbon?';

  /// Sample tags for questions.
  static const List<String> geographyTags = ['geography', 'population', 'cities'];
  static const List<String> physicsTags = ['physics', 'mass', 'planets'];
  static const List<String> timeTags = ['time', 'calendar', 'conversion'];
  static const List<String> physicsSpeedTags = ['physics', 'speed', 'light'];
  static const List<String> chemistryTags = ['chemistry', 'atoms', 'moles'];

  /// Sample unit mappings for US locale.
  static Map<String, String> get usUnitOptions => {
        'meter': 'Meter',
        'kilogram': 'Kilogram',
        'second': 'Second',
        'person': 'Person',
        'mole': 'Mole',
      };

  /// Sample unit mappings for EU locale.
  static Map<String, String> get euUnitOptions => {
        'meter': 'Metre',
        'kilogram': 'Kilogramme',
        'second': 'Seconde',
        'person': 'Personne',
        'mole': 'Mole',
      };

  /// Unit abbreviation to ID mapping for US locale.
  static Map<String, String> get usUnitAbbreviationToId => {
        'm': 'meter',
        'kg': 'kilogram',
        's': 'second',
        'p': 'person',
        'mol': 'mole',
      };

  /// Unit abbreviation to ID mapping for EU locale.
  static Map<String, String> get euUnitAbbreviationToId => {
        'm': 'meter',
        'kg': 'kilogramme',
        's': 'seconde',
        'p': 'personne',
        'mol': 'mole',
      };

  /// Unit ID to abbreviation mapping for US locale.
  static Map<String, String> get usUnitIdToAbbreviation => {
        'meter': 'm',
        'kilogram': 'kg',
        'second': 's',
        'person': 'p',
        'mole': 'mol',
      };

  /// Unit ID to abbreviation mapping for EU locale.
  static Map<String, String> get euUnitIdToAbbreviation => {
        'meter': 'm',
        'kilogramme': 'kg',
        'seconde': 's',
        'personne': 'p',
        'mole': 'mol',
      };

  /// Sample unit lists (abbreviations).
  static const List<String> lengthUnits = ['m', 'km', 'cm'];
  static const List<String> massUnits = ['kg', 'g', 'mg'];
  static const List<String> timeUnits = ['s', 'min', 'h'];
  static const List<String> countUnits = ['p', 'thousand', 'million'];
  static const List<String> chemistryUnits = ['mol', 'atoms'];

  /// Creates a RevealedQuestion for question 1 (population).
  static RevealedQuestion question1({
    String locale = 'US',
    int upvotes = 0,
    int myVoteVerdict = 0,
  }) {
    final isUS = locale == 'US';
    return RevealedQuestion(
      text: sampleQuestion1,
      tags: geographyTags,
      units: countUnits,
      unitOptions: isUS ? usUnitOptions : euUnitOptions,
      unitAbbreviationToId: isUS ? usUnitAbbreviationToId : euUnitAbbreviationToId,
      unitIdToAbbreviation: isUS ? usUnitIdToAbbreviation : euUnitIdToAbbreviation,
      upvotes: upvotes,
      category: 'PLANET_EARTH',
      myVoteVerdict: myVoteVerdict,
    );
  }

  /// Creates a RevealedQuestion for question 2 (mass).
  static RevealedQuestion question2({
    String locale = 'US',
    int upvotes = 0,
    int myVoteVerdict = 0,
  }) {
    final isUS = locale == 'US';
    return RevealedQuestion(
      text: sampleQuestion2,
      tags: physicsTags,
      units: massUnits,
      unitOptions: isUS ? usUnitOptions : euUnitOptions,
      unitAbbreviationToId: isUS ? usUnitAbbreviationToId : euUnitAbbreviationToId,
      unitIdToAbbreviation: isUS ? usUnitIdToAbbreviation : euUnitIdToAbbreviation,
      upvotes: upvotes,
      category: 'PLANET_EARTH',
      myVoteVerdict: myVoteVerdict,
    );
  }

  /// Creates a RevealedQuestion for question 3 (time).
  static RevealedQuestion question3({
    String locale = 'US',
    int upvotes = 0,
    int myVoteVerdict = 0,
  }) {
    final isUS = locale == 'US';
    return RevealedQuestion(
      text: sampleQuestion3,
      tags: timeTags,
      units: timeUnits,
      unitOptions: isUS ? usUnitOptions : euUnitOptions,
      unitAbbreviationToId: isUS ? usUnitAbbreviationToId : euUnitAbbreviationToId,
      unitIdToAbbreviation: isUS ? usUnitIdToAbbreviation : euUnitIdToAbbreviation,
      upvotes: upvotes,
      category: 'PLANET_EARTH',
      myVoteVerdict: myVoteVerdict,
    );
  }

  /// Creates a RevealedQuestion for question 4 (speed of light).
  static RevealedQuestion question4({
    String locale = 'US',
    int upvotes = 0,
    int myVoteVerdict = 0,
  }) {
    final isUS = locale == 'US';
    return RevealedQuestion(
      text: sampleQuestion4,
      tags: physicsSpeedTags,
      units: lengthUnits,
      unitOptions: isUS ? usUnitOptions : euUnitOptions,
      unitAbbreviationToId: isUS ? usUnitAbbreviationToId : euUnitAbbreviationToId,
      unitIdToAbbreviation: isUS ? usUnitIdToAbbreviation : euUnitIdToAbbreviation,
      upvotes: upvotes,
      category: 'PHYSICS',
      myVoteVerdict: myVoteVerdict,
    );
  }

  /// Creates a RevealedQuestion for question 5 (atoms).
  static RevealedQuestion question5({
    String locale = 'US',
    int upvotes = 0,
    int myVoteVerdict = 0,
  }) {
    final isUS = locale == 'US';
    return RevealedQuestion(
      text: sampleQuestion5,
      tags: chemistryTags,
      units: chemistryUnits,
      unitOptions: isUS ? usUnitOptions : euUnitOptions,
      unitAbbreviationToId: isUS ? usUnitAbbreviationToId : euUnitAbbreviationToId,
      unitIdToAbbreviation: isUS ? usUnitIdToAbbreviation : euUnitIdToAbbreviation,
      upvotes: upvotes,
      category: 'CHEMISTRY',
      myVoteVerdict: myVoteVerdict,
    );
  }

  /// Creates a unitless question (no units).
  static RevealedQuestion unitlessQuestion({
    String locale = 'US',
    int upvotes = 0,
    int myVoteVerdict = 0,
  }) {
    return RevealedQuestion(
      text: 'What is the value of pi?',
      tags: ['mathematics', 'constants'],
      units: const <String>[],
      unitOptions: const <String, String>{},
      unitAbbreviationToId: const <String, String>{},
      unitIdToAbbreviation: const <String, String>{},
      upvotes: upvotes,
      category: 'MATHEMATICS',
      myVoteVerdict: myVoteVerdict,
    );
  }

  /// Correct answer for question 1 (NYC population: ~8M).
  static AnswerValue correctAnswer1() => const AnswerValue(
        number: 8,
        orderOfMagnitude: 'M',
        unit: 'p',
      );

  /// Correct answer for question 2 (Earth mass: ~6e24 kg).
  static AnswerValue correctAnswer2() => const AnswerValue(
        number: 6,
        orderOfMagnitude: 'Qa',
        unit: 'kg',
      );

  /// Correct answer for question 3 (Seconds in year: ~3e7).
  static AnswerValue correctAnswer3() => const AnswerValue(
        number: 3,
        orderOfMagnitude: 'M',
        unit: 's',
      );

  /// Correct answer for question 4 (Speed of light: 3e8 m/s).
  static AnswerValue correctAnswer4() => const AnswerValue(
        number: 3,
        orderOfMagnitude: 'M',
        unit: 'm',
      );

  /// Correct answer for question 5 (Avogadro'\''s number: 6e23).
  static AnswerValue correctAnswer5() => const AnswerValue(
        number: 6,
        orderOfMagnitude: 'Qa',
        unit: 'mol',
      );

  /// Example percentile values for scoring (0.0 to 1.0).
  static const double highPercentile = 0.95;
  static const double mediumPercentile = 0.65;
  static const double lowPercentile = 0.25;

  /// Creates a list of question UIDs for a game.
  static List<String> questionUids({int count = 5}) {
    return List.generate(count, (i) => 'question_${i + 1}');
  }

  /// Creates a RevealPayload for a question.
  static RevealPayload revealPayload(AnswerValue correct) {
    return RevealPayload(correct: correct);
  }
}
