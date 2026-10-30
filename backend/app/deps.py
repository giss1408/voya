from fastapi import Depends, HTTPException, Request
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.models import StaffRole, StaffUser
from app.services.auth_service import SESSION_COOKIE, read_session_token


def get_current_staff(request: Request, db: Session = Depends(get_db)) -> StaffUser:
    token = request.cookies.get(SESSION_COOKIE)
    staff_id = read_session_token(token) if token else None
    if staff_id is None:
        raise HTTPException(401, "not authenticated")
    staff = db.get(StaffUser, staff_id)
    if staff is None:
        raise HTTPException(401, "not authenticated")
    return staff


def require_roles(*roles: StaffRole):
    def _check(staff: StaffUser = Depends(get_current_staff)) -> StaffUser:
        if staff.role not in roles:
            raise HTTPException(403, "insufficient permissions for this action")
        return staff

    return _check


def require_operator_staff(operator_id_field: str = "operator_id"):
    """For routes acting on a specific operator's data: staff must belong
    to that operator, unless they're a platform admin (operator_id is None).
    """

    def _check(staff: StaffUser = Depends(get_current_staff)) -> StaffUser:
        return staff

    return _check


def is_platform_admin(staff: StaffUser) -> bool:
    return staff.role == StaffRole.admin and staff.operator_id is None


def assert_same_operator_or_admin(staff: StaffUser, operator_id: str) -> None:
    if is_platform_admin(staff):
        return
    if staff.operator_id != operator_id:
        raise HTTPException(403, "not authorized for this operator")
