from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import assert_same_operator_or_admin, get_current_staff
from app.models.models import Booking, BookingStatus, StaffUser, Trip
from app.schemas.schemas import BookingDetailOut

router = APIRouter(tags=["manifest"])


@router.get("/trips/{trip_id}/manifest", response_model=list[BookingDetailOut])
def trip_manifest(
    trip_id: str,
    db: Session = Depends(get_db),
    staff: StaffUser = Depends(get_current_staff),
):
    trip = db.get(Trip, trip_id)
    if trip is None:
        raise HTTPException(404, "trip not found")
    assert_same_operator_or_admin(staff, trip.route.operator_id)
    bookings = (
        db.query(Booking)
        .filter(Booking.trip_id == trip_id, Booking.status != BookingStatus.cancelled)
        .all()
    )
    return bookings
