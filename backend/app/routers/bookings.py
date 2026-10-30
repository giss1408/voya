import io

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.models import Ticket
from app.schemas.schemas import (
    BookingCreate,
    BookingDetailOut,
    PaymentConfirm,
    SeatHoldOut,
    SeatHoldRequest,
    TicketVerifyRequest,
    TicketVerifyResult,
)
from app.services import booking_service

router = APIRouter(tags=["bookings"])


@router.post("/seat-holds", response_model=SeatHoldOut)
def create_seat_hold(payload: SeatHoldRequest, db: Session = Depends(get_db)):
    hold = booking_service.hold_seat(db, payload.trip_id, payload.seat_number, payload.rider_phone)
    return SeatHoldOut(hold_id=hold.id, seat_id=hold.seat_id, expires_at=hold.expires_at)


@router.post("/bookings", response_model=BookingDetailOut)
def create_booking(payload: BookingCreate, db: Session = Depends(get_db)):
    booking = booking_service.create_booking(
        db,
        hold_id=payload.hold_id,
        rider_name=payload.rider_name,
        rider_phone=payload.rider_phone,
        payer_phone=payload.payer_phone,
        payment_method=payload.payment_method,
        booking_source=payload.booking_source,
    )
    return booking


@router.get("/bookings/{booking_id}", response_model=BookingDetailOut)
def get_booking(booking_id: str, db: Session = Depends(get_db)):
    from fastapi import HTTPException

    from app.models.models import Booking

    booking = db.get(Booking, booking_id)
    if booking is None:
        raise HTTPException(404, "booking not found")
    return booking


@router.post("/bookings/{booking_id}/confirm-payment", response_model=BookingDetailOut)
def confirm_payment(booking_id: str, payload: PaymentConfirm, db: Session = Depends(get_db)):
    booking = booking_service.confirm_payment(db, booking_id, payload.psp_reference)
    return booking


@router.post("/tickets/verify", response_model=TicketVerifyResult)
def verify_ticket(payload: TicketVerifyRequest, db: Session = Depends(get_db)):
    result = booking_service.verify_ticket(db, payload.signed_token, payload.code)
    return TicketVerifyResult(**result)


@router.get("/tickets/{ticket_id}/qr.png")
def ticket_qr(ticket_id: str, db: Session = Depends(get_db)):
    import qrcode

    ticket = db.get(Ticket, ticket_id)
    if ticket is None:
        raise HTTPException(404, "ticket not found")

    img = qrcode.make(ticket.signed_token)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    return StreamingResponse(buf, media_type="image/png")
