"""Signed, offline-verifiable boarding tickets.

The signed token encodes booking/trip/seat/expiry and is HMAC-signed so a
driver's device (or this API acting on its behalf) can verify authenticity
without a database round-trip, and a photo of a ticket can't be replayed
for a different trip/date because the trip id and departure time are
baked into the signed payload.
"""
import base64
import hashlib
import hmac
import json
import random
from datetime import datetime, timedelta

from app.config import settings


def _sign(payload: dict) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    sig = hmac.new(settings.ticket_signing_key.encode(), raw, hashlib.sha256).digest()
    token = base64.urlsafe_b64encode(raw).decode() + "." + base64.urlsafe_b64encode(sig).decode()
    return token


def _verify(token: str) -> dict | None:
    try:
        raw_b64, sig_b64 = token.split(".")
        raw = base64.urlsafe_b64decode(raw_b64.encode())
        sig = base64.urlsafe_b64decode(sig_b64.encode())
    except (ValueError, Exception):
        return None
    expected = hmac.new(settings.ticket_signing_key.encode(), raw, hashlib.sha256).digest()
    if not hmac.compare_digest(sig, expected):
        return None
    return json.loads(raw)


def generate_fallback_code() -> str:
    return f"{random.randint(0, 999999):06d}"


def issue_ticket(booking_id: str, trip_id: str, seat_number: int, departure_at: datetime, operator_id: str) -> tuple[str, str]:
    """Returns (signed_token, 6-digit fallback code)."""
    payload = {
        "booking_id": booking_id,
        "trip_id": trip_id,
        "seat_number": seat_number,
        "departure_at": departure_at.isoformat(),
        "operator_id": operator_id,
        "expires_at": (departure_at + timedelta(hours=6)).isoformat(),
    }
    return _sign(payload), generate_fallback_code()


def verify_token(token: str) -> dict:
    payload = _verify(token)
    if payload is None:
        return {"valid": False, "reason": "signature_invalid"}
    expires_at = datetime.fromisoformat(payload["expires_at"])
    if datetime.utcnow() > expires_at:
        return {"valid": False, "reason": "expired"}
    return {"valid": True, **payload}
