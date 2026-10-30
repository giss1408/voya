from datetime import datetime, timedelta
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.config import settings
from app.models.models import (
    AgentLedgerEntry,
    Booking,
    BookingStatus,
    Payment,
    PaymentMethod,
    PaymentStatus,
    Seat,
    SeatHold,
    SeatStatus,
    Ticket,
    Trip,
)
from app.services import ticketing

AGENT_COMMISSION_RATE = Decimal("0.125")  # mid-point of the blueprint's 10-15% split


def hold_seat(db: Session, trip_id: str, seat_number: int, rider_phone: str) -> SeatHold:
    trip = db.get(Trip, trip_id)
    if trip is None:
        raise HTTPException(404, "trip not found")

    seat = (
        db.query(Seat)
        .filter(Seat.trip_id == trip_id, Seat.seat_number == seat_number)
        .with_for_update()
        .first()
    )
    if seat is None:
        raise HTTPException(404, "seat not found")

    _release_if_expired(db, seat)

    if seat.status != SeatStatus.available:
        raise HTTPException(409, "seat is not available")

    hold = SeatHold(
        trip_id=trip_id,
        seat_id=seat.id,
        rider_phone=rider_phone,
        expires_at=datetime.utcnow() + timedelta(seconds=settings.seat_hold_seconds),
    )
    db.add(hold)
    db.flush()

    seat.status = SeatStatus.held
    seat.hold_id = hold.id
    db.commit()
    db.refresh(hold)
    return hold


def _release_if_expired(db: Session, seat: Seat) -> None:
    if seat.status != SeatStatus.held or seat.hold_id is None:
        return
    hold = db.get(SeatHold, seat.hold_id)
    if hold is None or hold.released or hold.expires_at < datetime.utcnow():
        seat.status = SeatStatus.available
        seat.hold_id = None
        if hold is not None:
            hold.released = True


def create_booking(
    db: Session,
    hold_id: str,
    rider_name: str,
    rider_phone: str,
    payer_phone: str | None,
    payment_method: str,
    booking_source: str = "app",
    agent_id: str | None = None,
) -> Booking:
    hold = db.get(SeatHold, hold_id)
    if hold is None or hold.released:
        raise HTTPException(404, "hold not found or already released")
    if hold.expires_at < datetime.utcnow():
        raise HTTPException(409, "seat hold expired, search again")

    seat = db.get(Seat, hold.seat_id)
    trip = db.get(Trip, hold.trip_id)
    if seat is None or trip is None or seat.status != SeatStatus.held or seat.hold_id != hold.id:
        raise HTTPException(409, "seat hold is no longer valid")

    try:
        method = PaymentMethod(payment_method)
    except ValueError:
        raise HTTPException(400, "unsupported payment method")

    booking = Booking(
        trip_id=trip.id,
        seat_id=seat.id,
        rider_name=rider_name,
        rider_phone=rider_phone,
        payer_phone=payer_phone,
        booking_source=booking_source,
        agent_id=agent_id,
        status=BookingStatus.pending_payment,
    )
    db.add(booking)
    db.flush()

    payment = Payment(
        booking_id=booking.id,
        amount=trip.fare,
        method=method,
        status=PaymentStatus.pending,
    )
    db.add(payment)

    seat.status = SeatStatus.booked
    hold.released = True

    # Cash-on-boarding settles at boarding, not at booking time; everything
    # else waits for an explicit PSP confirmation.
    if method == PaymentMethod.cash_on_boarding:
        payment.status = PaymentStatus.confirmed
        booking.status = BookingStatus.confirmed
        _issue_ticket(db, booking, trip, seat)

        if agent_id is not None:
            commission = (trip.fare * AGENT_COMMISSION_RATE).quantize(Decimal("0.01"))
            db.add(
                AgentLedgerEntry(
                    agent_id=agent_id,
                    booking_id=booking.id,
                    amount=trip.fare,
                    commission=commission,
                )
            )

    db.commit()
    db.refresh(booking)
    return booking


def confirm_payment(db: Session, booking_id: str, psp_reference: str) -> Booking:
    booking = db.get(Booking, booking_id)
    if booking is None:
        raise HTTPException(404, "booking not found")
    if booking.payment is None:
        raise HTTPException(409, "booking has no payment record")
    if booking.status == BookingStatus.confirmed:
        return booking

    booking.payment.status = PaymentStatus.confirmed
    booking.payment.psp_reference = psp_reference
    booking.status = BookingStatus.confirmed

    trip = db.get(Trip, booking.trip_id)
    seat = db.get(Seat, booking.seat_id)
    _issue_ticket(db, booking, trip, seat)

    db.commit()
    db.refresh(booking)
    return booking


def _issue_ticket(db: Session, booking: Booking, trip: Trip, seat: Seat) -> Ticket:
    signed_token, code = ticketing.issue_ticket(
        booking_id=booking.id,
        trip_id=trip.id,
        seat_number=seat.seat_number,
        departure_at=trip.departure_at,
        operator_id=trip.route.operator_id,
    )
    ticket = Ticket(booking_id=booking.id, code=code, signed_token=signed_token)
    db.add(ticket)
    db.flush()
    return ticket


def verify_ticket(db: Session, signed_token: str | None, code: str | None) -> dict:
    if signed_token:
        result = ticketing.verify_token(signed_token)
        if not result["valid"]:
            return {"valid": False, "reason": result["reason"]}
        booking = db.get(Booking, result["booking_id"])
    elif code:
        ticket = db.query(Ticket).filter(Ticket.code == code).first()
        if ticket is None:
            return {"valid": False, "reason": "code_not_found"}
        booking = db.get(Booking, ticket.booking_id)
    else:
        return {"valid": False, "reason": "no_token_or_code_provided"}

    if booking is None or booking.status not in (BookingStatus.confirmed, BookingStatus.boarded):
        return {"valid": False, "reason": "booking_not_confirmed"}

    seat = db.get(Seat, booking.seat_id)
    if booking.status == BookingStatus.confirmed:
        booking.status = BookingStatus.boarded
        if booking.ticket:
            booking.ticket.verified_at = datetime.utcnow()
        db.commit()

    return {
        "valid": True,
        "rider_name": booking.rider_name,
        "seat_number": seat.seat_number if seat else None,
        "trip_id": booking.trip_id,
    }
