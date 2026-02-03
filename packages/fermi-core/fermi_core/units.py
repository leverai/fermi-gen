"""Utilities for quantity units using Pint.

MONEY and COUNT are treated as unitless. DATA_SIZE uses the same units across
regions. Do not persist these units in the database; include them inline in API
responses as needed.

This module is the canonical source for unit definitions, shared between
fermi-api and fermi-etl applications.
"""

import logging
from enum import StrEnum
from typing import TYPE_CHECKING, cast

import pint

from fermi_core.schemas.units import UnitInfo

if TYPE_CHECKING:
    from fermi_core.schemas.answers import AnswerBare

logger = logging.getLogger(__name__)

ureg = pint.UnitRegistry()


class Locale(StrEnum):
    """Locale of a user."""

    US = 'US'
    EU = 'EU'


# UnitsIds
# --- Mass ---
OUNCE = 'ounce'
POUND = 'pound'
TON = 'ton'
GRAM = 'gram'
KILOGRAM = 'kilogram'
METRIC_TON = 'metric_ton'
# --- Length ---
INCH = 'inch'
FOOT = 'foot'
MILE = 'mile'
CENTIMETER = 'centimeter'
METER = 'meter'
KILOMETER = 'kilometer'
# --- Area ---
FOOT2 = 'foot ** 2'
ACRE = 'acre'
MILE2 = 'mile ** 2'
METER2 = 'meter ** 2'
HECTARE = 'hectare'
KM2 = 'km ** 2'
# --- Volume ---
GALLON = 'gallon'
LITER = 'liter'
QUART = 'quart'
METER3 = 'meter ** 3'
FOOT3 = 'foot ** 3'
KM3 = 'km ** 3'
MILE3 = 'mile ** 3'
# --- Time ---
SECOND = 'second'
MINUTE = 'minute'
HOUR = 'hour'
DAY = 'day'
WEEK = 'week'
MONTH = 'month'
YEAR = 'year'
CENTURY = 'century'
MILLENNIUM = 'millennium'
# --- Temperature ---
FAHRENHEIT = 'fahrenheit'
CELSIUS = 'celsius'
# --- Data size ---
BIT = 'bit'
BYTE = 'byte'
KILOBYTE = 'kilobyte'
MEGABYTE = 'megabyte'
GIGABYTE = 'gigabyte'
TERABYTE = 'terabyte'
PETABYTE = 'petabyte'


_UNITS = {
    # --- Mass ---
    OUNCE: UnitInfo(id='ounce', abbreviation='oz', name='Ounce'),
    POUND: UnitInfo(id='pound', abbreviation='lb', name='Pound'),
    TON: UnitInfo(id='ton', abbreviation='ton', name='Ton'),
    GRAM: UnitInfo(id='gram', abbreviation='g', name='Gram'),
    KILOGRAM: UnitInfo(id='kilogram', abbreviation='kg', name='Kilogram'),
    METRIC_TON: UnitInfo(id='metric_ton', abbreviation='m. ton', name='Metric Ton'),
    # --- Length ---
    INCH: UnitInfo(id='inch', abbreviation='in', name='Inch'),
    FOOT: UnitInfo(id='foot', abbreviation='ft', name='Foot'),
    MILE: UnitInfo(id='mile', abbreviation='mi', name='Mile'),
    CENTIMETER: UnitInfo(id='centimeter', abbreviation='cm', name='Centimeter'),
    METER: UnitInfo(id='meter', abbreviation='m', name='Meter'),
    KILOMETER: UnitInfo(id='kilometer', abbreviation='km', name='Kilometer'),
    # --- Area ---
    FOOT2: UnitInfo(id='foot ** 2', abbreviation='ft²', name='Foot²'),
    ACRE: UnitInfo(id='acre', abbreviation='ac', name='Acre'),
    MILE2: UnitInfo(id='mile ** 2', abbreviation='mi²', name='Mile²'),
    METER2: UnitInfo(id='meter ** 2', abbreviation='m²', name='Meter²'),
    HECTARE: UnitInfo(id='hectare', abbreviation='ha', name='Hectare'),
    KM2: UnitInfo(id='km ** 2', abbreviation='km²', name='Kilometer²'),
    # --- Volume ---
    GALLON: UnitInfo(id='gallon', abbreviation='gal', name='Gallon'),
    LITER: UnitInfo(id='liter', abbreviation='L', name='Liter'),
    QUART: UnitInfo(id='quart', abbreviation='qt', name='Quart'),
    METER3: UnitInfo(id='meter ** 3', abbreviation='m³', name='Meter³'),
    FOOT3: UnitInfo(id='foot ** 3', abbreviation='ft³', name='Foot³'),
    KM3: UnitInfo(id='km ** 3', abbreviation='km³', name='Kilometer³'),
    MILE3: UnitInfo(id='mile ** 3', abbreviation='mi³', name='Mile³'),
    # --- Time ---
    SECOND: UnitInfo(id='second', abbreviation='s', name='Second'),
    MINUTE: UnitInfo(id='minute', abbreviation='min', name='Minute'),
    HOUR: UnitInfo(id='hour', abbreviation='h', name='Hour'),
    DAY: UnitInfo(id='day', abbreviation='d', name='Day'),
    WEEK: UnitInfo(id='week', abbreviation='wk', name='Week'),
    MONTH: UnitInfo(id='month', abbreviation='mo', name='Month'),
    YEAR: UnitInfo(id='year', abbreviation='yr', name='Year'),
    CENTURY: UnitInfo(id='century', abbreviation='cent', name='Century'),
    MILLENNIUM: UnitInfo(id='millennium', abbreviation='mill', name='Millennium'),
    # --- Temperature ---
    FAHRENHEIT: UnitInfo(id='fahrenheit', abbreviation='°F', name='Fahrenheit'),
    CELSIUS: UnitInfo(id='celsius', abbreviation='°C', name='Celsius'),
    # --- Data size ---
    BIT: UnitInfo(id='bit', abbreviation='bit', name='Bit'),
    BYTE: UnitInfo(id='byte', abbreviation='B', name='Byte'),
    KILOBYTE: UnitInfo(id='kilobyte', abbreviation='KB', name='Kilobyte'),
    MEGABYTE: UnitInfo(id='megabyte', abbreviation='MB', name='Megabyte'),
    GIGABYTE: UnitInfo(id='gigabyte', abbreviation='GB', name='Gigabyte'),
    TERABYTE: UnitInfo(id='terabyte', abbreviation='TB', name='Terabyte'),
    PETABYTE: UnitInfo(id='petabyte', abbreviation='PB', name='Petabyte'),
}

# Curated popular units per quantity type.
_QUANTITY_SYSTEM_UNITS_MAP: dict[str, dict[Locale, list[UnitInfo]]] = {
    # Mass
    'MASS': {
        Locale.US: [_UNITS[OUNCE], _UNITS[POUND], _UNITS[TON]],
        Locale.EU: [_UNITS[GRAM], _UNITS[KILOGRAM], _UNITS[METRIC_TON]],
    },
    # Length / distance
    'LENGTH': {
        Locale.US: [_UNITS[INCH], _UNITS[FOOT], _UNITS[MILE]],
        Locale.EU: [_UNITS[CENTIMETER], _UNITS[METER], _UNITS[KILOMETER]],
    },
    # Area
    'AREA': {
        Locale.US: [_UNITS[FOOT2], _UNITS[ACRE], _UNITS[MILE2]],
        Locale.EU: [_UNITS[METER2], _UNITS[HECTARE], _UNITS[KM2]],
    },
    # Volume
    'VOLUME': {
        Locale.US: [_UNITS[QUART], _UNITS[GALLON], _UNITS[FOOT3], _UNITS[MILE3]],
        Locale.EU: [_UNITS[LITER], _UNITS[METER3], _UNITS[KM3]],
    },
    # Time (common across regions)
    'TIME': {
        Locale.US: [
            _UNITS[SECOND],
            _UNITS[MINUTE],
            _UNITS[HOUR],
            _UNITS[DAY],
            _UNITS[WEEK],
            _UNITS[MONTH],
            _UNITS[YEAR],
            _UNITS[CENTURY],
            _UNITS[MILLENNIUM],
        ],
        Locale.EU: [
            _UNITS[SECOND],
            _UNITS[MINUTE],
            _UNITS[HOUR],
            _UNITS[DAY],
            _UNITS[WEEK],
            _UNITS[MONTH],
            _UNITS[YEAR],
            _UNITS[CENTURY],
            _UNITS[MILLENNIUM],
        ],
    },
    # Temperature (regional display preference)
    'TEMPERATURE': {
        Locale.US: [_UNITS[FAHRENHEIT]],
        Locale.EU: [_UNITS[CELSIUS]],
    },
    # Data size (not regional; mirror)
    'DATA_SIZE': {
        Locale.US: [
            _UNITS[BIT],
            _UNITS[BYTE],
            _UNITS[KILOBYTE],
            _UNITS[MEGABYTE],
            _UNITS[GIGABYTE],
            _UNITS[TERABYTE],
        ],
        Locale.EU: [
            _UNITS[BIT],
            _UNITS[BYTE],
            _UNITS[KILOBYTE],
            _UNITS[MEGABYTE],
            _UNITS[GIGABYTE],
            _UNITS[TERABYTE],
        ],
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


def get_unit_locale(unit_id: str) -> Locale:
    """Get the locale of a unit."""
    locale = _UNIT_LOCALE_MAP.get(unit_id)
    if locale is None:
        raise ValueError(f'Unit {unit_id} not found')
    return locale


def get_units_ladder(unit_id: str) -> list[UnitInfo]:
    """Get the units ladder for a given unit."""
    units_family = get_unit_family(unit_id)
    unit_locale = get_unit_locale(unit_id)
    units_ladder = units_family[unit_locale]
    return units_ladder


def convert_answer_to_user_unit(
    player_unit_id: str,
    correct_answer: 'AnswerBare',
) -> 'AnswerBare':
    """Convert an answer to the user's unit.

    Returns the correct answer converted to the same unit as the player's answer.
    The frontend is responsible for handling display constraints (e.g., capping values).
    """
    correct_quantity = ureg.Quantity(correct_answer['number'], correct_answer['unit'])
    converted_quantity = correct_quantity.to(player_unit_id)
    return cast(
        'AnswerBare',
        {
            'number': converted_quantity.magnitude,
            'unit': None if converted_quantity.dimensionless else player_unit_id,
        },
    )


def get_unit_info(unit_id: str) -> UnitInfo:
    """Get the unit info for a given unit."""
    unit = _UNITS.get(unit_id)
    if unit is None:
        raise ValueError(f'Unit {unit_id} not found')
    return unit


def swap_unit_to_locale(unit_id: str, target_locale: Locale) -> str:
    """Get the base unit of a target locale for the same quantity type.

    For example:
    - swap_unit_to_locale('pound', Locale.EU) -> 'kilogram'
    - swap_unit_to_locale('meter', Locale.US) -> 'foot'

    For quantity types that are the same across locales (TIME, DATA_SIZE),
    returns the original unit.

    Args:
        unit_id: The unit ID to convert from.
        target_locale: The target locale to get the base unit for.

    Returns:
        The base unit ID for the target locale.

    Raises:
        ValueError: If the unit is unknown.

    """
    qtype = _UNIT_QUANTITY_TYPE_MAP.get(unit_id)
    if qtype is None:
        raise ValueError(f'Unknown unit: {unit_id}')

    # Get the units for the target locale
    locale_units = _QUANTITY_SYSTEM_UNITS_MAP[qtype][target_locale]

    # Return the middle unit as a reasonable default (e.g., kg for mass, m for length)
    # This is typically the most commonly used unit for that quantity type
    middle_index = len(locale_units) // 2
    return locale_units[middle_index]['id']


def get_best_answer(answer: 'AnswerBare', locale: Locale | None = None) -> 'AnswerBare':
    """Convert the answer to the unit that gives a number <=1000."""
    # Get quantity in requested locale
    number, unit = answer['number'], answer['unit']
    quantity = ureg.Quantity(number, unit)
    if locale:
        quantity = quantity.to(swap_unit_to_locale(unit, locale))

    # Get ladder
    units_ladder = get_units_ladder(str(quantity.units))

    ## Loop through ladder from largest to smallest
    for unit_info in reversed(units_ladder):
        converted_quantity = quantity.to(unit_info['id'])
        if converted_quantity.magnitude >= 1:
            return {
                'number': converted_quantity.magnitude,
                'unit': str(converted_quantity.units),
            }

    # Otherwise, return as is
    return {
        'number': quantity.magnitude,
        'unit': str(quantity.units),
    }
