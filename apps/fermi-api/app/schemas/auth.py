"""Authentication schemas."""

from pydantic import BaseModel


class UserResponse(BaseModel):
    """User response schema."""

    firebase_uid: str
    email: str | None = None
    display_name: str | None = None
    picture: str | None = None
    locale: str | None = None


class TokenResponse(BaseModel):
    """Access token response schema."""

    access_token: str
    token_type: str
    user: UserResponse


class TokenPayload(BaseModel):
    """Access token schema."""

    user_id: int


class Token(BaseModel):
    """Token schema."""

    access_token: str
    token_type: str
