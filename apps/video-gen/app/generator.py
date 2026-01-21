"""Video generator for daily question videos.

Refactored from scripts/video_gen/generate_daily_video.py with print statements
replaced by structured logging.
"""

import logging
import random
import textwrap
from pathlib import Path
from typing import ClassVar

import numpy as np
from fermi_core.units import Locale, get_best_answer, get_unit_info
from fermi_db.models.game import Fermi
from google.cloud import texttospeech
from moviepy.audio.AudioClip import CompositeAudioClip
from moviepy.audio.io.AudioFileClip import AudioFileClip
from moviepy.video.compositing.CompositeVideoClip import CompositeVideoClip
from moviepy.video.fx import FadeIn, FadeOut
from moviepy.video.VideoClip import ColorClip, ImageClip
from num2words import num2words
from PIL import Image, ImageDraw, ImageFont

logger = logging.getLogger(__name__)

# Theme Constants from AppTheme
BG_DARK = (26, 31, 46)  # Converted roughly from HSL(220, 0.20, 0.10) to RGB
TEXT_COLOR = (242, 244, 247)  # Soft White
PRIMARY_COLOR = (108, 92, 231)  # Vibrant Indigo
SURVIVAL_COLOR = (245, 124, 60)  # Vibrant Orange

# Font path
FONT_PATH = 'assets/ubuntu/Ubuntu-B.ttf'


def _get_font_path() -> str:
    """Get available font path."""
    if Path(FONT_PATH).exists():
        return FONT_PATH
    # Fallback for macOS/local dev
    return 'Arial'


class VideoGenerator:
    """Generate a video of the Daily Question."""

    # Google Cloud TTS "Journey" voices are expressive and adult-sounding
    VOICES: ClassVar[tuple[str, ...]] = ('en-US-Journey-D', 'en-US-Journey-F')

    def __init__(self, output_dir: Path, assets_dir: Path | None = None):
        """Initialize the VideoGenerator.

        Args:
            output_dir: Directory to write output files.
            assets_dir: Directory containing assets (icon.png, etc.).

        """
        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.assets_dir = assets_dir or Path(__file__).parent.parent / 'assets'
        self.tts_client = texttospeech.TextToSpeechClient()
        self._font_path = _get_font_path()

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
        """Create an ImageClip with text using Pillow."""
        img = Image.new('RGBA', size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        font = ImageFont.truetype(self._font_path, fontsize)

        # Wrap text
        avg_char_width = fontsize * 0.5
        wrap_width = int((size[0] - 100) / avg_char_width)
        lines = textwrap.wrap(text, width=wrap_width)

        # Calculate total height to center vertically
        bbox = draw.textbbox((0, 0), 'Wg', font=font)
        line_height = bbox[3] - bbox[1] + 10
        total_text_height = len(lines) * line_height

        y_text = (size[1] - total_text_height) // 2

        for line in lines:
            line_bbox = draw.textbbox((0, 0), line, font=font)
            line_width = line_bbox[2] - line_bbox[0]
            x_text = (size[0] - line_width) // 2
            draw.text((x_text, y_text), line, font=font, fill=color)
            y_text += line_height

        return ImageClip(np.array(img), duration=duration)

    def create_outro_clip(self, duration: int = 5) -> ImageClip:
        """Create an outro clip prompting downloads."""
        img = Image.new('RGBA', (1080, 1920), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        title_font = ImageFont.truetype(self._font_path, 80)
        body_font = ImageFont.truetype(self._font_path, 50)

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

        # Add QR Codes with preserved aspect ratio
        target_height = 350
        qr_y = 1200
        spacing = 60

        apple_path = self.assets_dir / 'apple.png'
        android_path = self.assets_dir / 'android.png'

        if apple_path.exists() and android_path.exists():
            # Load images
            apple_img = Image.open(apple_path).convert('RGBA')
            android_img = Image.open(android_path).convert('RGBA')

            # Calculate new size maintaining aspect ratio
            def get_new_size(img: Image.Image, target_h: int) -> tuple[int, int]:
                aspect_ratio = img.width / img.height
                return int(target_h * aspect_ratio), target_h

            apple_w, apple_h = get_new_size(apple_img, target_height)
            android_w, android_h = get_new_size(android_img, target_height)

            # Resize
            apple_qr = apple_img.resize((apple_w, apple_h), Image.Resampling.LANCZOS)
            android_qr = android_img.resize(
                (android_w, android_h),
                Image.Resampling.LANCZOS,
            )

            # Calculate centering
            total_width = apple_w + android_w + spacing
            start_x = (1080 - total_width) // 2

            # Paste Apple QR (Left)
            img.paste(apple_qr, (start_x, qr_y), apple_qr)

            # Paste Android QR (Right)
            img.paste(
                android_qr,
                (start_x + apple_w + spacing, qr_y),
                android_qr,
            )
        else:
            logger.warning('QR Code assets not found')

        return ImageClip(np.array(img), duration=duration)

    def create_countdown_clip(self, duration: int) -> CompositeVideoClip:
        """Create a visual countdown clip."""
        clips = []
        step = 1
        size = (400, 400)

        for i in range(duration, 0, -1):
            txt_clip = self.text_to_image_clip(
                str(i),
                fontsize=200,
                color=SURVIVAL_COLOR,
                size=size,
                duration=step,
            ).with_start(duration - i)
            clips.append(txt_clip)

        return CompositeVideoClip(clips, size=size)

    def create_video(self, fermi: Fermi) -> Path:
        """Create a video for the given Fermi question.

        Args:
            fermi: The Fermi question to generate a video for.

        Returns:
            Path to the generated video file.

        """
        logger.info('Generating video', extra={'question': fermi.text[:50]})

        # Select Voice
        voice_name = random.choice(self.VOICES)
        logger.info('Using voice', extra={'voice': voice_name})

        # 1. Setup Audio
        q_audio_path = self.generate_tts(
            fermi.text,
            'question_audio',
            voice_name=voice_name,
        )
        q_audio_clip = AudioFileClip(q_audio_path)

        # Convert number to words for natural TTS pronunciation
        # e.g., 5800000 -> "five million, eight hundred thousand"
        best_answer = (
            {'number': fermi.number, 'unit': ''}
            if not fermi.unit
            else get_best_answer(
                {'number': fermi.number, 'unit': fermi.unit},
                locale=Locale.US,
            )
        )
        number, unit_id = best_answer['number'], best_answer['unit']
        number_in_words = num2words(int(number))
        unit_info = get_unit_info(unit_id) if unit_id else None
        unit_text = unit_info['name'] if unit_id else ''
        unit_abbr = unit_info['abbreviation'] if unit_id else ''

        ans_text_spoken = f'The answer is {number_in_words} {unit_text}'.strip()
        ans_audio_path = self.generate_tts(
            ans_text_spoken,
            'answer_audio',
            voice_name=voice_name,
        )
        ans_audio_clip = AudioFileClip(ans_audio_path)

        # 2. Timing logic
        start_delay = 1.0
        t_q_start = start_delay
        d_q = q_audio_clip.duration

        d_countdown = 5
        t_countdown_start = t_q_start + d_q

        t_ans_start = t_countdown_start + d_countdown
        d_ans = ans_audio_clip.duration
        d_ans_visual = max(d_ans, 4.0)

        t_outro_start = t_ans_start + d_ans_visual

        # Load outro voice (pre-generated asset matching the selected voice)
        outro_voice_path = self.assets_dir / f'outro_voice_{voice_name}.mp3'
        outro_voice_clip = None
        if outro_voice_path.exists():
            outro_voice_clip = AudioFileClip(str(outro_voice_path))
            d_outro = max(5.0, outro_voice_clip.duration + 0.5)
        else:
            logger.warning(
                'Outro voice not found',
                extra={'path': str(outro_voice_path)},
            )
            d_outro = 5.0

        total_duration = t_outro_start + d_outro

        # 3. Create Video Clips
        bg_clip = ColorClip(size=(1080, 1920), color=BG_DARK, duration=total_duration)

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

        countdown_clip = self.create_countdown_clip(d_countdown)
        countdown_clip = countdown_clip.with_start(t_countdown_start).with_position(
            ('center', 1100),
        )

        answer_text_visual = f'{number:,.0f} {unit_abbr}'
        answer_clip = (
            self.text_to_image_clip(
                answer_text_visual,
                fontsize=100,
                color='#6C5CE7',
                duration=d_ans_visual,
            )
            .with_start(t_ans_start)
            .with_position('center')
            .with_effects([FadeIn(0.5)])
        )

        outro_clip = self.create_outro_clip(duration=int(d_outro)).with_start(
            t_outro_start,
        )

        # Logo in outro
        logo_path = self.assets_dir / 'icon.png'
        logo_clip = None
        if logo_path.exists():
            logo_clip = (
                ImageClip(str(logo_path))
                .with_duration(d_outro)
                .resized(height=400)
                .with_start(t_outro_start)
                .with_position(('center', 200))
            )
        else:
            logger.warning('Logo not found', extra={'path': str(logo_path)})

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

        # Outro voice (call-to-action)
        if outro_voice_clip:
            audio_clips.append(outro_voice_clip.with_start(t_outro_start))

        # Background Music
        bg_music_path = self.assets_dir / 'background_music.mp3'
        if bg_music_path.exists():
            logger.info('Adding background music')
            from moviepy.audio.fx.MultiplyVolume import MultiplyVolume

            bg_music = AudioFileClip(str(bg_music_path)).subclipped(0, total_duration)
            bg_music = bg_music.with_effects([MultiplyVolume(0.12)])
            audio_clips.append(bg_music)
        else:
            logger.warning(
                'Background music not found',
                extra={'path': str(bg_music_path)},
            )

        final_audio = CompositeAudioClip(audio_clips)
        final_video = final_video.with_audio(final_audio)
        final_video = final_video.with_duration(total_duration)

        output_filename = self.output_dir / f'fermi_{fermi.uid}.mp4'
        logger.info('Writing video file', extra={'output': str(output_filename)})

        final_video.write_videofile(
            str(output_filename),
            fps=24,
            codec='libx264',
            audio_codec='aac',
        )

        logger.info('Video saved', extra={'path': str(output_filename)})
        return output_filename
