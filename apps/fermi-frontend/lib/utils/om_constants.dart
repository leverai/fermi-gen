/// Order of Magnitude (OM) constants used throughout the application.
/// This provides a single source of truth for OM values and their multipliers.
///
/// Order of magnitude symbols in ascending order:
/// '', K (thousand), M (million), B (billion), T (trillion), Qa (quadrillion)
const List<String> orderOfMagnitudeSymbols = ['', 'K', 'M', 'B', 'T', 'Qa'];

/// Human-readable words for each order of magnitude (ascending).
const List<String> orderOfMagnitudeWords = [
  '',
  'thousand',
  'million',
  'billion',
  'trillion',
  'quadrillion',
];

/// Multipliers for each order of magnitude symbol.
/// Used to convert from (number, OM) format to absolute value.
const Map<String, int> orderOfMagnitudeMultipliers = {
  '': 1,
  'K': 1000,
  'M': 1000000,
  'B': 1000000000,
  'T': 1000000000000,
  'Qa': 1000000000000000,
};

/// Power of 10 for each order of magnitude symbol.
/// Used for logarithmic calculations: value = number × 10^magnitude
const Map<String, int> orderOfMagnitudePowers = {
  '': 0,
  'K': 3,
  'M': 6,
  'B': 9,
  'T': 12,
  'Qa': 15,
};
