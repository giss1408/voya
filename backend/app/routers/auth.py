from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_staff, is_platform_admin
from app.models.models import StaffRole, StaffUser
from app.schemas.schemas import LoginRequest, StaffCreate, StaffOut
from app.services import auth_service

router = APIRouter(tags=["auth"])


@router.post("/auth/login", response_model=StaffOut)
def login(payload: LoginRequest, response: Response, db: Session = Depends(get_db)):
    staff = auth_service.authenticate(db, payload.phone, payload.password)
    if staff is None:
        raise HTTPException(401, "invalid phone or password")

    token = auth_service.create_session_token(staff.id)
    response.set_cookie(
        auth_service.SESSION_COOKIE,
        token,
        max_age=auth_service.SESSION_MAX_AGE,
        httponly=True,
        samesite="lax",
    )
    return staff


@router.post("/auth/logout")
def logout(response: Response):
    response.delete_cookie(auth_service.SESSION_COOKIE)
    return {"ok": True}


@router.get("/auth/me", response_model=StaffOut)
def me(staff: StaffUser = Depends(get_current_staff)):
    return staff


@router.post("/staff", response_model=StaffOut)
def create_staff(
    payload: StaffCreate,
    db: Session = Depends(get_db),
    requester: StaffUser = Depends(get_current_staff),
):
    try:
        role = StaffRole(payload.role)
    except ValueError:
        raise HTTPException(400, "unknown role")

    # A platform admin may create staff for any operator (or another
    # platform admin). An operator admin may only add staff to their own
    # operator and can't mint platform admins.
    if is_platform_admin(requester):
        operator_id = payload.operator_id
    else:
        if requester.role != StaffRole.admin:
            raise HTTPException(403, "only an admin can add staff")
        if role == StaffRole.admin and payload.operator_id is None:
            raise HTTPException(403, "cannot create a platform admin")
        operator_id = requester.operator_id
        if payload.operator_id and payload.operator_id != requester.operator_id:
            raise HTTPException(403, "cannot create staff for another operator")

    if db.query(StaffUser).filter(StaffUser.phone == payload.phone).first():
        raise HTTPException(409, "a staff account already uses this phone number")

    staff = StaffUser(
        operator_id=operator_id,
        name=payload.name,
        phone=payload.phone,
        password_hash=auth_service.hash_password(payload.password),
        role=role,
    )
    db.add(staff)
    db.commit()
    db.refresh(staff)
    return staff
