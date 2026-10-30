"""USSD menu state machine for Voya Agent (*920#).

Telco USSD gateways are stateless per request: each keypress arrives as a
fresh HTTP call carrying session_id and the *entire* text typed so far
("1*2*09"), not just the latest key. We derive the current screen from
that text and persist richer state (selected route/trip/seat) in
UssdSession.data between requests, since the telco doesn't carry it for us.
"""
import json
from datetime import date, datetime

from sqlalchemy.orm import Session

from app.models.models import Route, Seat, Trip
from app.services import booking_service

MAX_LIST = 5


def handle(db: Session, session) -> tuple[str, bool]:
    """Returns (message, continue_session)."""
    state = json.loads(session.data or "{}")
    keys = [k for k in session.text.split("*") if k != ""] if session.text else []
    last_key = keys[-1] if keys else None

    screen = state.get("screen", "root")

    try:
        if last_key is None:
            _save(state, "root")
            return _show_root()

        if screen == "root":
            return dispatch_root(db, state, last_key)
        if screen == "awaiting_route":
            return _handle_route_choice(db, state, last_key)
        if screen == "awaiting_trip":
            return _handle_trip_choice(db, state, last_key)
        if screen == "awaiting_seat":
            return _handle_seat_choice(db, state, last_key, session)
        if screen == "awaiting_name":
            # Free text (a name) may itself contain "*"; take the raw
            # remainder after the last menu selection instead of last_key.
            name = session.text.split("*")[-1]
            return _handle_name(db, state, name, session)

        _save(state, "root")
        return _show_root()
    finally:
        session.data = json.dumps(state)


def _save(state: dict, screen: str, **extra) -> None:
    state.clear()
    state["screen"] = screen
    state.update(extra)


def _show_root() -> tuple[str, bool]:
    return (
        "CON Welcome to Voya\n1. Book a seat\n2. My last ticket code\n0. Exit",
        True,
    )


def dispatch_root(db: Session, state: dict, key: str) -> tuple[str, bool]:
    if key == "1":
        routes = db.query(Route).filter(Route.is_active.is_(True)).limit(MAX_LIST).all()
        if not routes:
            return "END No routes available right now.", False
        lines = [f"{i + 1}. {r.origin} - {r.destination}" for i, r in enumerate(routes)]
        _save(state, "awaiting_route", route_ids=[r.id for r in routes])
        return "CON Choose a route:\n" + "\n".join(lines), True
    if key == "0":
        return "END Thank you for using Voya.", False
    return "END Invalid option.", False


def _handle_route_choice(db: Session, state: dict, key: str) -> tuple[str, bool]:
    route_ids = state.get("route_ids", [])
    idx = _to_index(key, len(route_ids))
    if idx is None:
        return "END Invalid selection. Dial *920# to try again.", False

    route = db.get(Route, route_ids[idx])
    today = date.today()
    trips = (
        db.query(Trip)
        .filter(Trip.route_id == route.id, Trip.departure_at >= datetime.combine(today, datetime.min.time()))
        .order_by(Trip.departure_at)
        .limit(MAX_LIST)
        .all()
    )
    if not trips:
        return "END No upcoming trips on this route.", False

    lines = [
        f"{i + 1}. {t.departure_at.strftime('%d/%m %H:%M')} - {t.fare} seats left:"
        f" {sum(1 for s in t.seats if s.status.value == 'available')}"
        for i, t in enumerate(trips)
    ]
    _save(state, "awaiting_trip", trip_ids=[t.id for t in trips])
    return "CON Choose a trip:\n" + "\n".join(lines), True


def _handle_trip_choice(db: Session, state: dict, key: str) -> tuple[str, bool]:
    trip_ids = state.get("trip_ids", [])
    idx = _to_index(key, len(trip_ids))
    if idx is None:
        return "END Invalid selection. Dial *920# to try again.", False

    trip = db.get(Trip, trip_ids[idx])
    available = sorted(
        (s for s in trip.seats if s.status.value == "available"), key=lambda s: s.seat_number
    )[:MAX_LIST]
    if not available:
        return "END Sorry, this trip is fully booked.", False

    lines = [f"{i + 1}. Seat {s.seat_number}" for i, s in enumerate(available)]
    _save(state, "awaiting_seat", trip_id=trip.id, seat_numbers=[s.seat_number for s in available])
    return "CON Choose a seat:\n" + "\n".join(lines), True


def _handle_seat_choice(db: Session, state: dict, key: str, session) -> tuple[str, bool]:
    seat_numbers = state.get("seat_numbers", [])
    idx = _to_index(key, len(seat_numbers))
    if idx is None:
        return "END Invalid selection. Dial *920# to try again.", False

    seat_number = seat_numbers[idx]
    try:
        hold = booking_service.hold_seat(db, state["trip_id"], seat_number, session.phone)
    except Exception:
        return "END That seat was just taken. Dial *920# to try again.", False

    _save(state, "awaiting_name", hold_id=hold.id, trip_id=state["trip_id"], seat_number=seat_number)
    return "CON Enter your full name for the ticket:", True


def _handle_name(db: Session, state: dict, raw_name: str, session) -> tuple[str, bool]:
    name = raw_name.strip()
    if not name:
        return "END Name cannot be empty. Dial *920# to try again.", False

    try:
        booking = booking_service.create_booking(
            db,
            hold_id=state["hold_id"],
            rider_name=name,
            rider_phone=session.phone,
            payer_phone=None,
            payment_method="cash_on_boarding",
            booking_source="ussd",
        )
    except Exception:
        return "END Your seat hold expired. Dial *920# to try again.", False

    code = booking.ticket.code if booking.ticket else "N/A"
    return (
        f"END Booked! Seat {state['seat_number']}. Show code {code} to board. "
        "An SMS confirmation will follow.",
        False,
    )


def _to_index(key: str, length: int) -> int | None:
    if not key.isdigit():
        return None
    idx = int(key) - 1
    if 0 <= idx < length:
        return idx
    return None
