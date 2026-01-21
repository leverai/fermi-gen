from dataclasses import dataclass
from pathlib import Path

from app.generator import VideoGenerator


@dataclass
class Fermi:
    uid: str = '123'
    text: str = 'What is 2+2?'
    number: int = 4
    unit: str = 'kilometer'


gen = VideoGenerator(
    Path(__file__).parent.parent,
    Path(__file__).parent.parent / 'assets',
)
gen.create_video(Fermi())
