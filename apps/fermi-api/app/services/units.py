"""Utilities for quantity units using Pint.

MONEY and COUNT are treated as unitless. DATA_SIZE uses the same units across
regions. Do not persist these units in the database; include them inline in API
responses as needed.
"""

import logging
from collections.abc import Generator

import pint
from fermi_db.schemas import AnswerBare, Locale

from app.schemas.game import UnitInfo

logger = logging.getLogger(__name__)

ureg = pint.UnitRegistry()

# --- Mass ---
OUNCE = UnitInfo(id='ounce', abbreviation='oz', name='Ounce')
POUND = UnitInfo(id='pound', abbreviation='lb', name='Pound')
TON_US = UnitInfo(id='ton', abbreviation='ton', name='Ton')  # short ton
GRAM = UnitInfo(id='gram', abbreviation='g', name='Gram')
KILOGRAM = UnitInfo(id='kilogram', abbreviation='kg', name='Kilogram')
TON_METRIC = UnitInfo(id='metric_ton', abbreviation='ton', name='Ton')  # metric ton

# --- Length ---
INCH = UnitInfo(id='inch', abbreviation='in', name='Inch')
FOOT = UnitInfo(id='foot', abbreviation='ft', name='Foot')
MILE = UnitInfo(id='mile', abbreviation='mi', name='Mile')
CENTIMETER = UnitInfo(id='centimeter', abbreviation='cm', name='Centimeter')
METER = UnitInfo(id='meter', abbreviation='m', name='Meter')
KILOMETER = UnitInfo(id='kilometer', abbreviation='km', name='Kilometer')

# --- Area ---
FOOT2 = UnitInfo(id='foot ** 2', abbreviation='ft²', name='Foot²')
ACRE = UnitInfo(id='acre', abbreviation='ac', name='Acre')
MILE2 = UnitInfo(id='mile ** 2', abbreviation='mi²', name='Mile²')
METER2 = UnitInfo(id='meter ** 2', abbreviation='m²', name='Meter²')
HECTARE = UnitInfo(id='hectare', abbreviation='ha', name='Hectare')
KM2 = UnitInfo(id='km ** 2', abbreviation='km²', name='Kilometer²')

# --- Volume ---
GALLON = UnitInfo(id='gallon', abbreviation='gal', name='Gallon')
LITER = UnitInfo(id='liter', abbreviation='L', name='Liter')
QUART = UnitInfo(id='quart', abbreviation='qt', name='Quart')
METER3 = UnitInfo(id='meter ** 3', abbreviation='m³', name='Meter³')
FOOT3 = UnitInfo(id='foot ** 3', abbreviation='ft³', name='Foot³')
KM3 = UnitInfo(id='km ** 3', abbreviation='km³', name='Kilometer³')
MILE3 = UnitInfo(id='mile ** 3', abbreviation='mi³', name='Mile³')

# --- Time ---
SECOND = UnitInfo(id='second', abbreviation='s', name='Second')
MINUTE = UnitInfo(id='minute', abbreviation='min', name='Minute')
HOUR = UnitInfo(id='hour', abbreviation='h', name='Hour')
DAY = UnitInfo(id='day', abbreviation='d', name='Day')
WEEK = UnitInfo(id='week', abbreviation='wk', name='Week')
MONTH = UnitInfo(id='month', abbreviation='mo', name='Month')
YEAR = UnitInfo(id='year', abbreviation='yr', name='Year')
CENTURY = UnitInfo(id='century', abbreviation='cent', name='Century')
MILLENNIUM = UnitInfo(id='millennium', abbreviation='mill', name='Millennium')

# --- Temperature ---
FAHRENHEIT = UnitInfo(id='fahrenheit', abbreviation='°F', name='Fahrenheit')
CELSIUS = UnitInfo(id='celsius', abbreviation='°C', name='Celsius')

# --- Data size ---
KILOBYTE = UnitInfo(id='kilobyte', abbreviation='KB', name='Kilobyte')
MEGABYTE = UnitInfo(id='megabyte', abbreviation='MB', name='Megabyte')
GIGABYTE = UnitInfo(id='gigabyte', abbreviation='GB', name='Gigabyte')
TERABYTE = UnitInfo(id='terabyte', abbreviation='TB', name='Terabyte')
PETABYTE = UnitInfo(id='petabyte', abbreviation='PB', name='Petabyte')


# Curated popular units per quantity type.
_QUANTITY_SYSTEM_UNITS_MAP: dict[str, dict[Locale, list[UnitInfo]]] = {
    # Mass
    'MASS': {
        Locale.US: [OUNCE, POUND, TON_US],
        Locale.EU: [GRAM, KILOGRAM, TON_METRIC],
    },
    # Length / distance
    'LENGTH': {
        Locale.US: [INCH, FOOT, MILE],
        Locale.EU: [CENTIMETER, METER, KILOMETER],
    },
    # Area
    'AREA': {
        Locale.US: [FOOT2, ACRE, MILE2],
        Locale.EU: [METER2, HECTARE, KM2],
    },
    # Volume
    'VOLUME': {
        Locale.US: [QUART, GALLON, FOOT3, MILE3],
        Locale.EU: [LITER, METER3, KM3],
    },
    # Time (common across regions)
    'TIME': {
        Locale.US: [SECOND, MINUTE, HOUR, DAY, WEEK, MONTH, YEAR, CENTURY, MILLENNIUM],
        Locale.EU: [SECOND, MINUTE, HOUR, DAY, WEEK, MONTH, YEAR, CENTURY, MILLENNIUM],
    },
    # Temperature (regional display preference)
    'TEMPERATURE': {
        Locale.US: [FAHRENHEIT],
        Locale.EU: [CELSIUS],
    },
    # Data size (not regional; mirror)
    'DATA_SIZE': {
        Locale.US: [KILOBYTE, MEGABYTE, GIGABYTE, TERABYTE],
        Locale.EU: [KILOBYTE, MEGABYTE, GIGABYTE, TERABYTE],
    },
}

# Map of unit to quantity type
_UNIT_QUANTITY_TYPE_MAP: dict[str, str] = {
    unit['id']: qtype
    for qtype, locales in _QUANTITY_SYSTEM_UNITS_MAP.items()
    for _, units in locales.items()
    for unit in units
}

_UNIT_LOCALE_MAP: dict[str, Locale] = {
    unit['id']: locale
    for _, locales in _QUANTITY_SYSTEM_UNITS_MAP.items()
    for locale, units in locales.items()
    for unit in units
}


def get_unit_family(
    unit: str,
) -> dict[Locale, list[UnitInfo]]:
    """Return curated US/EU units for a given unit.

    For example, if the unit is "kg", the result will be
    {
        'US': [OUNCE, POUND, TON_US],
        'EU': [GRAM, KILOGRAM, TON_METRIC],
    }

    The keys in the result are "US" (US customary) and "EU" (metric/SI).
    Unknown types return empty lists for both systems.
    """
    qtype = _UNIT_QUANTITY_TYPE_MAP.get(unit)
    if qtype is None:
        raise ValueError(f'Unknown unit: {unit}')
    return _QUANTITY_SYSTEM_UNITS_MAP[qtype]


def get_units_ladder(unit_id: str) -> list[UnitInfo]:
    """Get the units ladder for a given unit."""
    units_family = get_unit_family(unit_id)
    unit_locale = get_unit_locale(unit_id)
    units_ladder = units_family[unit_locale]
    return units_ladder


def step_down_units_ladder(unit_id: str) -> Generator[str, None, None]:
    """Iterate up a unit in the units ladder."""
    units_ladder = get_units_ladder(unit_id)
    units_ids_ladder = [unit['id'] for unit in units_ladder]
    unit_idx = units_ids_ladder.index(unit_id)
    yield from units_ids_ladder[unit_idx::-1]


def convert_answer_to_user_unit(
    player_unit_id: str,
    correct_answer: AnswerBare,
) -> AnswerBare:
    """Convert an answer to the user's unit, or smaller units until magnitude >= 1."""
    correct_quantity = ureg.Quantity(correct_answer['number'], correct_answer['unit'])
    converted_quantity = correct_quantity
    for unit_id in step_down_units_ladder(player_unit_id):
        converted_quantity = correct_quantity.to(unit_id)
        if converted_quantity.magnitude >= 1:
            break
    logger.warning('Answer %s is too small with all units', correct_answer)
    return AnswerBare(
        number=converted_quantity.magnitude,
        unit=None
        if converted_quantity.dimensionless
        else str(converted_quantity.units),
    )


def get_unit_locale(unit_id: str) -> Locale:
    """Get the locale of a unit."""
    locale = _UNIT_LOCALE_MAP.get(unit_id)
    if locale is None:
        raise ValueError(f'Unit {unit_id} not found')
    return locale
