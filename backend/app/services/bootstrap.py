from sqlalchemy.orm import Session

from app.config import settings
from app.models.models import StaffRole, StaffUser
from app.services import auth_service


def ensure_platform_admin(db: Session) -> None:
    """Dev convenience: guarantee one platform-admin login exists so the
    first operator can be verified and the first staff accounts created.
    Credentials come from env vars; change the password in any shared
    deployment.
    """
    phone = settings.admin_phone
    exists = db.query(StaffUser).filter(StaffUser.phone == phone).first()
    if exists:
        return

    admin = StaffUser(
        operator_id=None,
        name="Platform Admin",
        phone=phone,
        password_hash=auth_service.hash_password(settings.admin_password),
        role=StaffRole.admin,
    )
    db.add(admin)
    db.commit()
