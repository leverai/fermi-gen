"""Script to generate a video of the Daily Question."""
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "moviepy",
#     "google-cloud-texttospeech",
#     "pillow",
#     "fermi-db",
#     "sqlmodel",
#     "sqlalchemy",
# ]
# [tool.uv.sources]
# fermi-db = { path = "../../packages/fermi-db", editable = true }
# fermi-core = { path = "../../packages/fermi-core", editable = true }
# ///

import datetime
import os
import random
import textwrap
import uuid
from pathlib import Path
from typing import ClassVar

# Mock Fermi object if DB connection fails or for testing
from fermi_db.models.game import Fermi, QuestionCategory, QuestionDifficulty
from google.cloud import texttospeech
from moviepy.audio.AudioClip import CompositeAudioClip
from moviepy.audio.io.AudioFileClip import AudioFileClip
from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
from moviepy.video.fx import FadeIn, FadeOut
from moviepy.video.VideoClip import ColorClip, ImageClip
from PIL import Image, ImageDraw, ImageFont

# Theme Constants from AppTheme
BG_DARK = (26, 31, 46)  # Converted roughly from HSL(220, 0.20, 0.10) to RGB
TEXT_COLOR = (242, 244, 247)  # Soft White
PRIMARY_COLOR = (108, 92, 231)  # Vibrant Indigo
SURVIVAL_COLOR = (245, 124, 60)  # Vibrant Orange

ASSETS_DIR = Path(__file__).parent
FONT_PATH = '/usr/share/fonts/truetype/ubuntu/Ubuntu-B.ttf'  # Fallback font
if not os.path.exists(FONT_PATH):
    FONT_PATH = 'Arial'  # System fallback


class VideoGenerator:
    """Generates a video of the Daily Question."""

    # Google Cloud TTS "Journey" voices are expressive and adult-sounding
    VOICES: ClassVar[list[str]] = ['en-US-Journey-D', 'en-US-Journey-F']

    def __init__(self, output_dir: str = 'output'):
        """Initialize the VideoGenerator."""
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.tts_client = texttospeech.TextToSpeechClient()

    def generate_tts(
        self,
        text: str,
        filename: str,
        voice_name: str | None = None,
    ) -> str:
        """Generate TTS audio file using Google Cloud TTS."""
        if not voice_name:
            voice_name = random.choice(self.VOICES)

        synthesis_input = texttospeech.SynthesisInput(text=text)
        voice = texttospeech.VoiceSelectionParams(
            language_code='en-US',
            name=voice_name,
            ssml_gender=texttospeech.SsmlVoiceGender.MALE
            if 'Journey-D' in voice_name
            else texttospeech.SsmlVoiceGender.FEMALE,
        )
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3,
        )
        response = self.tts_client.synthesize_speech(
            input=synthesis_input,
            voice=voice,
            audio_config=audio_config,
        )

        filepath = self.output_dir / f'{filename}.mp3'
        with open(filepath, 'wb') as out:
            out.write(response.audio_content)
        return str(filepath)

    def text_to_image_clip(
        self,
        text: str,
        fontsize: int = 50,
        color: str | tuple = 'white',
        size: tuple = (1080, 1920),
        duration: int = 5,
    ) -> ImageClip:
        """Create an ImageClip with text using Pillow (more robust than TextClip)."""
        # Create image
        img = Image.new('RGBA', size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # Load font
        font = ImageFont.truetype(FONT_PATH, fontsize)

        # Wrap text
        # Approx char width logic could be improved, but this is a rough est.
        # 1080 width / (fontsize * 0.6) approx chars
        avg_char_width = fontsize * 0.5
        wrap_width = int((size[0] - 100) / avg_char_width)
        lines = textwrap.wrap(text, width=wrap_width)

        # Draw text
        # Calculate total height to center vertically
        # Getting line height roughly
        bbox = draw.textbbox((0, 0), 'Wg', font=font)
        line_height = bbox[3] - bbox[1] + 10
        total_text_height = len(lines) * line_height

        y_text = (size[1] - total_text_height) // 2

        for line in lines:
            # Center horizontally
            line_bbox = draw.textbbox((0, 0), line, font=font)
            line_width = line_bbox[2] - line_bbox[0]
            x_text = (size[0] - line_width) // 2
            draw.text((x_text, y_text), line, font=font, fill=color)
            y_text += line_height

        # Convert to numpy for MoviePy
        import numpy as np

        return ImageClip(np.array(img), duration=duration)

    def create_outro_clip(self, duration: int = 5) -> ImageClip:
        """Create an outro clip prompting downloads."""
        # Using Pillow to draw the outro card
        img = Image.new('RGBA', (1080, 1920), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        # Load fonts - Prioritize local fonts folder
        title_font = ImageFont.truetype(FONT_PATH, 80)
        body_font = ImageFont.truetype(FONT_PATH, 50)

        # Draw "Download Guesstimate"
        text = 'Download\nGuesstimate'
        w, h = draw.textbbox((0, 0), text, font=title_font)[2:]
        draw.text(
            ((1080 - w) / 2, 700),
            text,
            font=title_font,
            fill='white',
            align='center',
        )

        # Draw "Available on iOS & Android"
        subtext = 'Available on iOS & Android'
        w, h = draw.textbbox((0, 0), subtext, font=body_font)[2:]
        draw.text(
            ((1080 - w) / 2, 1000),
            subtext,
            font=body_font,
            fill=TEXT_COLOR,
            align='center',
        )

        import numpy as np

        return ImageClip(np.array(img), duration=duration)

    def create_countdown_clip(self, duration: int) -> CompositeVideoClip:
        """Create a visual countdown clip."""
        clips = []
        # We want to count down from duration to 1
        # Each number lasts approx 1 second
        step = 1

        # Size for the countdown numbers
        size = (400, 400)

        for i in range(duration, 0, -1):
            txt_clip = self.text_to_image_clip(
                str(i),
                fontsize=200,
                color=SURVIVAL_COLOR,  # Use orange
                size=size,
                duration=step,
            ).with_start(duration - i)
            # Add a simple fade / pulse effect if possible, or just plain switch
            clips.append(txt_clip)

        # Return a composite clip of the defined size, not full screen
        return CompositeVideoClip(clips, size=size)

    def create_video(self, fermi: Fermi) -> None:
        """Create a video for the given Fermi question."""
        print(f'Generating video for question: {fermi.text}')

        # Select Voice for this video
        voice_name = random.choice(self.VOICES)
        print(f'Using Voice: {voice_name}')

        # 1. Setup Audio
        # Question
        # Start immediately after 1s delay
        q_audio_path = self.generate_tts(
            fermi.text,
            'question_audio',
            voice_name=voice_name,
        )
        q_audio_clip = AudioFileClip(q_audio_path)

        # Answer
        # Start with a direct answer
        ans_text_spoken = f'The answer is {fermi.number:,.0f} {fermi.unit or ""}'
        ans_audio_path = self.generate_tts(
            ans_text_spoken,
            'answer_audio',
            voice_name=voice_name,
        )
        ans_audio_clip = AudioFileClip(ans_audio_path)

        # 2. Timing logic
        start_delay = 1.0

        # Question starts
        t_q_start = start_delay
        d_q = q_audio_clip.duration

        # Countdown starts after question
        d_countdown = 5
        t_countdown_start = t_q_start + d_q

        # Answer starts after countdown
        t_ans_start = t_countdown_start + d_countdown
        d_ans = ans_audio_clip.duration
        d_ans_visual = max(d_ans, 4.0)  # Ensure text stays long enough

        # Outro starts after answer
        t_outro_start = t_ans_start + d_ans_visual
        d_outro = 5.0

        total_duration = t_outro_start + d_outro

        # 3. Create Video Clips

        # Background
        bg_clip = ColorClip(size=(1080, 1920), color=BG_DARK, duration=total_duration)

        # Question Text
        # Visible from t_q_start until Answer reveals (t_ans_start)
        q_text_clip = (
            self.text_to_image_clip(
                fermi.text,
                fontsize=70,
                color='white',
                duration=(t_ans_start - t_q_start),
            )
            .with_start(t_q_start)
            .with_effects([FadeOut(0.5)])
        )

        # Countdown
        # Visible during countdown phase
        countdown_clip = self.create_countdown_clip(d_countdown)

        # Position the smaller countdown clip in the lower center
        # Center x is automatic if we use 'center'. y=1200
        countdown_clip = countdown_clip.with_start(t_countdown_start).with_position(
            ('center', 1100),
        )

        # Answer Text
        answer_text_visual = f'{fermi.number:,.0f} {fermi.unit or ""}'
        answer_clip = (
            self.text_to_image_clip(
                answer_text_visual,
                fontsize=100,
                color='#6C5CE7',  # Primary color
                duration=d_ans_visual,
            )
            .with_start(t_ans_start)
            .with_position('center')
            .with_effects([FadeIn(0.5)])
        )

        # Outro
        outro_clip = self.create_outro_clip(duration=d_outro).with_start(t_outro_start)

        # Large Logo in Outro - Prioritize local icons
        logo_path = ASSETS_DIR / 'icon-fg.png'
        if not logo_path.exists():
            logo_path = ASSETS_DIR / 'icons/icon-fg.png'
        if not logo_path.exists():
            logo_path = ASSETS_DIR / 'icon.png'
        if not logo_path.exists():
            logo_path = ASSETS_DIR / 'icons/icon.png'

        logo_clip = None
        if logo_path.exists():
            logo_clip = (
                ImageClip(str(logo_path))
                .with_duration(d_outro)
                .resized(height=400)  # Made it big
                .with_start(t_outro_start)
                .with_position(('center', 200))  # Top area of outro
            )

        # 4. Composite
        video_clips = [bg_clip, q_text_clip, countdown_clip, answer_clip, outro_clip]
        if logo_clip:
            video_clips.append(logo_clip)

        final_video = CompositeVideoClip(video_clips)

        # 5. Audio Composition
        audio_clips = [
            q_audio_clip.with_start(t_q_start),
            ans_audio_clip.with_start(t_ans_start),
        ]

        # Background Music - Look for background_music.mp3 in the same folder
        bg_music_path = ASSETS_DIR / 'background_music.mp3'

        if not bg_music_path.exists():
            # Check music subfolder
            bg_music_path = ASSETS_DIR / 'music/background_music.mp3'

        if bg_music_path.exists():
            print(f'Adding background music from {bg_music_path}')
            from moviepy.audio.fx.Volumex import Volumex

            bg_music = AudioFileClip(str(bg_music_path)).subclipped(0, total_duration)

            bg_music = bg_music.with_effects([Volumex(0.1)])  # Low volume
            audio_clips.append(bg_music)
        else:
            print(
                f'WARNING: Background music not found at {bg_music_path}. '
                'Please place an mp3 file there.',
            )

        final_audio = CompositeAudioClip(audio_clips)

        final_video = final_video.with_audio(final_audio)
        final_video = final_video.with_duration(total_duration)

        output_filename = self.output_dir / f'fermi_{fermi.uid}.mp4'
        final_video.write_videofile(
            str(output_filename),
            fps=24,
            codec='libx264',
            audio_codec='aac',
        )
        print(f'Video saved to {output_filename}')


def main() -> None:
    """Generate the daily video."""
    # Mock Data for dev
    mock_fermi = Fermi(
        uid=uuid.uuid4(),
        question_id=1,
        text='How many piano tuners are there in Chicago?',
        question_source={},
        answer_id=1,
        number=250,
        unit=None,
        snippet='Classic Fermi problem.',
        used_ai_overview=False,
        difficulty=QuestionDifficulty.MEDIUM,
        category=QuestionCategory.OTHER,
        random_sort_key=1,
        created_at=datetime.datetime.now(tz=datetime.timezone.UTC),
        updated_at=datetime.datetime.now(tz=datetime.timezone.UTC),
        # Default mock values for required fields
        gpt_5_1_number=0,
        gpt_5_1_unit='',
        gpt_5_mini_number=0,
        gpt_5_mini_unit='',
        gpt_5_nano_number=0,
        gpt_5_nano_unit='',
        gemini_flash_1_number=0,
        gemini_flash_1_unit='',
        gemini_flash_2_number=0,
        gemini_flash_2_unit='',
        gemini_flash_3_number=0,
        gemini_flash_3_unit='',
        gemini_flash_4_number=0,
        gemini_flash_4_unit='',
        gemini_flash_5_number=0,
        gemini_flash_5_unit='',
    )

    gen = VideoGenerator()
    gen.create_video(mock_fermi)


if __name__ == '__main__':
    main()
