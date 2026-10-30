from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import PlainTextResponse
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_staff
from app.models.models import AgentLedgerEntry, StaffRole, StaffUser, UssdSession
from app.schemas.schemas import AgentBookingCreate, BookingDetailOut, UssdRequest
from app.services import booking_service, ussd_service

router = APIRouter(tags=["agent"])


def require_agent(staff: StaffUser = Depends(get_current_staff)) -> StaffUser:
    if staff.role not in (StaffRole.agent, StaffRole.admin):
        raise HTTPException(403, "agent role required")
    return staff


@router.post("/agent/bookings", response_model=BookingDetailOut)
def agent_create_booking(
    payload: AgentBookingCreate,
    db: Session = Depends(get_db),
    agent: StaffUser = Depends(require_agent),
):
    """Kiosk-side booking: the agent sells a seat for cash and earns a
    commission, same booking engine as the app and USSD paths."""
    booking = booking_service.create_booking(
        db,
        hold_id=payload.hold_id,
        rider_name=payload.rider_name,
        rider_phone=payload.rider_phone,
        payer_phone=None,
        payment_method=payload.payment_method,
        booking_source="agent",
        agent_id=agent.id,
    )
    return booking


@router.get("/agent/ledger")
def agent_ledger(db: Session = Depends(get_db), agent: StaffUser = Depends(require_agent)):
    entries = db.query(AgentLedgerEntry).filter(AgentLedgerEntry.agent_id == agent.id).all()
    return [
        {
            "booking_id": e.booking_id,
            "amount": str(e.amount),
            "commission": str(e.commission),
            "created_at": e.created_at,
        }
        for e in entries
    ]


@router.post("/ussd", response_class=PlainTextResponse)
def ussd_gateway(payload: UssdRequest, db: Session = Depends(get_db)):
    """Carrier-facing webhook. No auth — carriers authenticate via IP
    allowlist/shared secret at the gateway level in production, not here.

    Request/response shape follows the common Africa's Talking-style
    convention: plain text "CON ..." (keep session open) or "END ..."
    (close it), since real USSD gateways expect exactly this format.
    """
    session = db.get(UssdSession, payload.session_id)
    if session is None:
        session = UssdSession(id=payload.session_id, phone=payload.phone)
        db.add(session)

    session.phone = payload.phone
    session.text = payload.text  # scratch attribute, not persisted as a column
    session.updated_at = datetime.utcnow()

    message, continue_session = ussd_service.handle(db, session)

    if not continue_session:
        db.delete(session)
    db.commit()

    return message
