"""Test video generation."""

from dataclasses import dataclass
from pathlib import Path

from app.generator import VideoGenerator


@dataclass
class Fermi:
    """mock fermi object."""

    uid: str = '123'
    text: str = (
        'What is 2+2 because two plus two is a very important '
        'question for you to answer?'
    )
    number: int = 4
    unit: str = 'kilometer'


gen = VideoGenerator(
    Path(__file__).parent.parent,
    Path(__file__).parent.parent / 'assets',
)
gen.create_video(Fermi())
