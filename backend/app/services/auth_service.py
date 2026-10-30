import bcrypt
from itsdangerous import BadSignature, URLSafeTimedSerializer
from sqlalchemy.orm import Session

from app.config import settings
from app.models.models import StaffUser

_serializer = URLSafeTimedSerializer(settings.ticket_signing_key, salt="voya-session")

SESSION_COOKIE = "voya_session"
SESSION_MAX_AGE = 60 * 60 * 12  # 12h


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode()[:72], bcrypt.gensalt()).decode()


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode()[:72], password_hash.encode())
    except ValueError:
        return False


def create_session_token(staff_id: str) -> str:
    return _serializer.dumps({"staff_id": staff_id})


def read_session_token(token: str) -> str | None:
    try:
        payload = _serializer.loads(token, max_age=SESSION_MAX_AGE)
    except BadSignature:
        return None
    return payload.get("staff_id")


def authenticate(db: Session, phone: str, password: str) -> StaffUser | None:
    user = db.query(StaffUser).filter(StaffUser.phone == phone).first()
    if user is None or not verify_password(password, user.password_hash):
        return None
    return user
