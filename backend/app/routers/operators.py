from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import assert_same_operator_or_admin, get_current_staff, is_platform_admin
from app.models.models import Operator, OperatorStatus, StaffUser, Vehicle
from app.schemas.schemas import (
    OperatorCreate,
    OperatorOut,
    OperatorStatusUpdate,
    VehicleCreate,
    VehicleOut,
)

router = APIRouter(prefix="/operators", tags=["operators"])


@router.post("", response_model=OperatorOut)
def create_operator(payload: OperatorCreate, db: Session = Depends(get_db)):
    # Open signup — anyone can apply to become an operator. The account
    # starts "pending" and can't list routes until a platform admin
    # verifies it (see POST /operators/{id}/status).
    operator = Operator(**payload.model_dump())
    db.add(operator)
    db.commit()
    db.refresh(operator)
    return operator


@router.get("", response_model=list[OperatorOut])
def list_operators(
    db: Session = Depends(get_db),
    staff: StaffUser = Depends(get_current_staff),
):
    if is_platform_admin(staff):
        return db.query(Operator).all()
    return db.query(Operator).filter(Operator.id == staff.operator_id).all()


@router.get("/{operator_id}", response_model=OperatorOut)
def get_operator(
    operator_id: str,
    db: Session = Depends(get_db),
    staff: StaffUser = Depends(get_current_staff),
):
    assert_same_operator_or_admin(staff, operator_id)
    operator = db.get(Operator, operator_id)
    if operator is None:
        raise HTTPException(404, "operator not found")
    return operator


@router.post("/{operator_id}/status", response_model=OperatorOut)
def update_operator_status(
    operator_id: str,
    payload: OperatorStatusUpdate,
    db: Session = Depends(get_db),
    staff: StaffUser = Depends(get_current_staff),
):
    if not is_platform_admin(staff):
        raise HTTPException(403, "only a platform admin can approve or suspend an operator")

    operator = db.get(Operator, operator_id)
    if operator is None:
        raise HTTPException(404, "operator not found")

    try:
        operator.status = OperatorStatus(payload.status)
    except ValueError:
        raise HTTPException(400, "unknown status")

    db.commit()
    db.refresh(operator)
    return operator


@router.post("/vehicles", response_model=VehicleOut)
def create_vehicle(
    payload: VehicleCreate,
    db: Session = Depends(get_db),
    staff: StaffUser = Depends(get_current_staff),
):
    assert_same_operator_or_admin(staff, payload.operator_id)
    if db.get(Operator, payload.operator_id) is None:
        raise HTTPException(404, "operator not found")
    vehicle = Vehicle(**payload.model_dump())
    db.add(vehicle)
    db.commit()
    db.refresh(vehicle)
    return vehicle


@router.get("/{operator_id}/vehicles", response_model=list[VehicleOut])
def list_vehicles(
    operator_id: str,
    db: Session = Depends(get_db),
    staff: StaffUser = Depends(get_current_staff),
):
    assert_same_operator_or_admin(staff, operator_id)
    return db.query(Vehicle).filter(Vehicle.operator_id == operator_id).all()
