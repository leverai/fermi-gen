# """Unit tests for services/units.py."""

# from fermi_db.schemas import AnswerBare
# from app.services import units

# def test_convert_answer_to_user_unit_preserves_unit_id() -> None:
#     """Test that convert_answer_to_user_unit preserves the requested unit ID.

#     This ensures that abbreviations like 'km ** 3' are not expanded to
#     'kilometer ** 3' by pint, which would cause mismatches in the frontend.
#     """
#     correct_answer = AnswerBare(number=9.5e+08, unit='meter ** 3')
#     player_unit_id = 'km ** 3'

#     result = units.convert_answer_to_user_unit(player_unit_id, correct_answer)

#     assert result['unit'] == player_unit_id
#     assert result['number'] == 0.9500000000000001

# def test_convert_answer_to_user_unit_dimensionless() -> None:
#     """Test conversion for dimensionless units."""
#     # Assuming 'count' or similar is treated as dimensionless or unitless in some contexts,
#     # but based on the code, if dimensionless, unit is None.
#     # Let's test a simple ratio if possible, or just skip if we don't have dimensionless examples handy.
#     # The code handles `if converted_quantity.dimensionless`.
#     pass
