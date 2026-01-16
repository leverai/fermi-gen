"""Serve the account deletion instructions page."""

from fastapi import APIRouter
from fastapi.responses import HTMLResponse
from opentelemetry import trace

import app.logging.attributes as api_attrs

router = APIRouter()

html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Account Deletion - Guesstimate: Not Trivia!</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
            padding: 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        h1 {
            color: #000;
            font-size: 32px;
            margin-bottom: 10px;
            font-weight: bold;
        }

        .subtitle {
            color: #595959;
            font-size: 16px;
            margin-bottom: 30px;
        }

        .intro {
            font-size: 16px;
            color: #333;
            margin-bottom: 30px;
            line-height: 1.8;
        }

        .steps-section {
            margin-bottom: 40px;
        }

        .steps-title {
            font-size: 24px;
            font-weight: bold;
            color: #000;
            margin-bottom: 20px;
        }

        .steps-list {
            list-style: decimal;
            padding-left: 30px;
            margin-bottom: 0;
        }

        .steps-list li {
            font-size: 16px;
            color: #333;
            margin-bottom: 15px;
            line-height: 1.8;
        }

        .screenshot-container {
            width: 100%;
            margin: 20px 0;
            text-align: center;
            background: #f9f9f9;
            padding: 0;
            border-radius: 8px;
            overflow: hidden;
        }

        .screenshot-container img {
            width: 100%;
            height: auto;
            object-fit: contain;
            border-radius: 0;
            box-shadow: none;
            display: block;
        }

        .screenshot-caption {
            margin-top: 0;
            padding: 8px 12px;
            font-size: 12px;
            color: #666;
            font-style: italic;
            line-height: 1.4;
        }

        .data-section {
            margin-top: 20px;
            padding: 25px;
            background: #f9f9f9;
            border-radius: 8px;
            border-left: 4px solid #3030F1;
            overflow: hidden;
        }

        .data-section::after {
            content: "";
            display: table;
            clear: both;
        }

        .data-title {
            font-size: 20px;
            font-weight: bold;
            color: #000;
            margin-bottom: 15px;
        }

        .data-content {
            font-size: 15px;
            color: #333;
            line-height: 1.8;
        }

        .data-content ul {
            margin-top: 10px;
            padding-left: 25px;
        }

        .data-content li {
            margin-bottom: 8px;
        }

        .retention-section {
            margin-top: 20px;
            padding: 20px;
            background: #fff3cd;
            border-radius: 8px;
            border-left: 4px solid #ffc107;
        }

        .retention-title {
            font-size: 18px;
            font-weight: bold;
            color: #856404;
            margin-bottom: 10px;
        }

        .retention-content {
            font-size: 15px;
            color: #856404;
            line-height: 1.8;
        }

        .contact-section {
            margin-top: 40px;
            padding: 25px;
            background: #e7f3ff;
            border-radius: 8px;
            border-left: 4px solid #3030F1;
            overflow: hidden;
        }

        .contact-title {
            font-size: 20px;
            font-weight: bold;
            color: #000;
            margin-bottom: 15px;
        }

        .contact-content {
            font-size: 15px;
            color: #333;
            line-height: 1.8;
        }

        .contact-content a {
            color: #3030F1;
            text-decoration: none;
        }

        .contact-content a:hover {
            text-decoration: underline;
        }

        @media (max-width: 768px) {
            .container {
                padding: 20px;
            }

            h1 {
                font-size: 24px;
            }

            .steps-title {
                font-size: 20px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Account Deletion Request</h1>
        <p class="subtitle">Guesstimate: Not Trivia! by LEVER AI LLC</p>

        <div class="intro">
            <h2>We're sad to see you go!</h2>
            <p>Follow the steps below to delete your account and ALL of your data from <strong>Guesstimate: Not Trivia!</strong>.</p>
        </div>

        <div class="steps-section">
            <h2 class="steps-title">Steps to Delete Your Account</h2>
            <div class="screenshot-container">
                <img src="/static/account-deletion-guide.png" alt="Account deletion guide screenshot showing the steps to delete your account in Guesstimate: Not Trivia!">
                <p class="screenshot-caption">Visual guide showing where to find the account deletion option in the Guesstimate: Not Trivia! app</p>
            </div>
            <ol class="steps-list">
                <li>Open the <strong>Guesstimate: Not Trivia!</strong> app on your device</li>
                <li><strong>Open the settings menu</strong> by clicking on the gear icon in the bottom right corner.</li>
                <li><strong>Click "Delete account"</strong> at the bottom of the menu.</li>
                <li>Confirm that you want to permanently delete your account.</li>
            </ol>
        </div>

        <div class="data-section">
            <h2 class="data-title">What Data Will Be Deleted</h2>
            <div class="data-content">
                <p>When you delete your account, we delete EVERYTHING, including:</p>
                <ul>
                    <li>Your user account information (email, display name, profile settings)</li>
                    <li>Your game history and statistics</li>
                    <li>Your progress and achievements</li>
                    <li>Your saved preferences and settings</li>
                    <li>Any personal information associated with your account</li>
                </ul>
            </div>
        </div>

        <div class="contact-section">
            <h2 class="contact-title">Need Help?</h2>
            <div class="contact-content">
                <p>If you have any questions about account deletion or need assistance with the process, please contact us:</p>
                <p>
                    <strong>Email:</strong> <a href="mailto:support@leverai.tech">support@leverai.tech</a><br>
                    <strong>Developer:</strong> LEVER AI LLC
                </p>
                <p>You can also submit a data subject access request through our <a href="/api/v1/privacy-policy">Privacy Policy</a> page.</p>
            </div>
        </div>
    </div>
</body>
</html>
"""  # noqa: E501


@router.get('/account-deletion', response_class=HTMLResponse)
async def get_account_deletion_instructions() -> HTMLResponse:
    """Serve the account deletion instructions HTML page."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_account_deletion_instructions.__qualname__)

    return HTMLResponse(content=html, status_code=200)
