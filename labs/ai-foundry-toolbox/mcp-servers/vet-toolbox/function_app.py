"""
Veterinary Practice MCP Server (Azure Functions, Python)

Exposes three MCP tools for a veterinary practice:
  1. get_patient_summary    - returns a randomised, consolidated clinical summary for a
                               patient: recent visits, vaccination/microchip status, and
                               any upcoming appointment
  2. schedule_appointment   - books a new (randomised/simulated) appointment for a
                               patient, optionally on a preferred date, and returns a
                               confirmation
  3. order_stock            - checks current stock of a veterinary medicine at a clinic
                               location and optionally places an order to top it up

Tool design notes:
  Tools are grouped around user intent rather than mirroring individual
  backend endpoints:
    - `get_patient_summary` merges what would otherwise be several separate
      "get history" / "get vaccination status" / "get next appointment" calls
      into the single question a client or vet actually asks: "bring me up
      to speed on this patient". Returning everything relevant in one call
      avoids forcing an agent to chain multiple round-trips for what is
      conceptually one task.
    - `schedule_appointment` is an action tool (it creates a booking) rather
      than a read-only lookup, giving the agent an actual next step instead
      of just surfacing information.
    - `order_stock` intentionally combines "check stock" and "place an
      order" into a single call, since an agent/user naturally thinks of
      "manage stock for this medicine" as one task rather than juggling
      separate check/order primitives.
  Every response returns a stable, fully keyed schema (e.g. the `order`
  object on `order_stock` is always present with the same fields, using a
  `status` of "not_requested" vs "placed" instead of sometimes returning
  null) so callers can rely on consistent output shapes.

This is a scaffold: all data is generated randomly in-memory to simulate a
backend system (e.g. a practice management system / pharmacy inventory API).
Replace the `_random_*` helper functions with real data-source calls when
integrating with production systems.
"""

import logging
import random
import uuid
from datetime import datetime, timedelta, timezone
from enum import Enum

import azure.functions as func
from pydantic import BaseModel, Field, ValidationError, field_validator

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


# ---------------------------------------------------------------------------
# Static reference data used to randomise realistic-looking responses
# ---------------------------------------------------------------------------

_VET_NAMES = [
    "Dr. Amelia Clarke",
    "Dr. Rajesh Patel",
    "Dr. Sofia Rossi",
    "Dr. Liam O'Connor",
    "Dr. Emily Nguyen",
]

_VISIT_REASONS = [
    "Annual wellness check",
    "Vaccination booster",
    "Dental cleaning",
    "Skin allergy follow-up",
    "Post-surgery check-up",
    "Limping / lameness assessment",
    "Ear infection treatment",
    "Weight management consultation",
    "Routine blood panel",
    "Microchip registration",
]

_DIAGNOSES = [
    "Healthy, no concerns found",
    "Mild ear infection, prescribed antibiotics",
    "Seasonal skin allergy",
    "Early-stage dental tartar build-up",
    "Slight weight gain, dietary advice given",
    "Fully recovered from previous surgery",
    "Mild arthritis in hind legs",
    "Up to date on all vaccinations",
]

class MedicineName(str, Enum):
    AMOXICILLIN = "Amoxicillin"
    MELOXICAM = "Meloxicam"
    APOQUEL = "Apoquel"
    RIMADYL = "Rimadyl"
    FRONTLINE_PLUS = "Frontline Plus"
    HEARTGARD = "Heartgard"
    METACAM = "Metacam"
    CERENIA = "Cerenia"
    BRAVECTO = "Bravecto"
    VETMEDIN = "Vetmedin"


_MEDICATIONS = {
    MedicineName.AMOXICILLIN: "Antibiotic",
    MedicineName.MELOXICAM: "Anti-inflammatory / pain relief",
    MedicineName.APOQUEL: "Allergy / anti-itch",
    MedicineName.RIMADYL: "Anti-inflammatory / pain relief",
    MedicineName.FRONTLINE_PLUS: "Flea & tick prevention",
    MedicineName.HEARTGARD: "Heartworm prevention",
    MedicineName.METACAM: "Anti-inflammatory / pain relief",
    MedicineName.CERENIA: "Anti-nausea",
    MedicineName.BRAVECTO: "Flea & tick prevention",
    MedicineName.VETMEDIN: "Heart medication",
}

_MEDICINE_LOOKUP = {medicine.value.lower(): medicine for medicine in MedicineName}


class OrderStockRequest(BaseModel):
    medicine_name: MedicineName
    location: str | None = None
    quantity_to_order: int = Field(default=0, ge=0)

    @field_validator("medicine_name", mode="before")
    @classmethod
    def normalize_medicine_name(cls, value):
        if isinstance(value, MedicineName):
            return value
        if isinstance(value, str):
            parsed = _MEDICINE_LOOKUP.get(value.strip().lower())
            if parsed is not None:
                return parsed
        raise ValueError("Unknown medicine_name")

_CLINIC_LOCATIONS = [
    "Riverside Veterinary Clinic - Main St",
    "Riverside Veterinary Clinic - North Branch",
    "Riverside Veterinary Clinic - Warehouse",
]

_VACCINES = [
    "Rabies",
    "DHPP (Distemper/Parvo)",
    "Bordetella (Kennel Cough)",
    "FVRCP (Feline Distemper)",
    "Leptospirosis",
]


def _random_vaccination_status() -> list:
    statuses = []
    for vaccine in random.sample(_VACCINES, k=random.randint(2, len(_VACCINES))):
        last_given = _random_past_datetime(max_days_back=400)
        valid_years = random.choice([1, 3])
        due_date = last_given + timedelta(days=365 * valid_years)
        statuses.append(
            {
                "vaccine": vaccine,
                "last_given": last_given.strftime("%Y-%m-%d"),
                "due_date": due_date.strftime("%Y-%m-%d"),
                "up_to_date": due_date > datetime.now(timezone.utc),
            }
        )
    return statuses


def _random_past_datetime(max_days_back: int = 730) -> datetime:
    days_back = random.randint(1, max_days_back)
    return datetime.now(timezone.utc) - timedelta(days=days_back)


def _random_future_datetime(max_days_forward: int = 180) -> datetime:
    days_forward = random.randint(1, max_days_forward)
    hour = random.choice([9, 10, 11, 13, 14, 15, 16])
    dt = datetime.now(timezone.utc) + timedelta(days=days_forward)
    return dt.replace(hour=hour, minute=random.choice([0, 15, 30, 45]), second=0, microsecond=0)


# ---------------------------------------------------------------------------
# Tool 1: get_patient_summary
# ---------------------------------------------------------------------------

@app.mcp_tool()
@app.mcp_tool_property(arg_name="patient_name", description="The name of the animal patient.", is_required=True)
@app.mcp_tool_property(arg_name="client_name", description="The name of the client (the patient's owner).", is_required=True)
@app.mcp_tool_property(arg_name="species", description="The species of the patient, e.g. dog, cat, rabbit.", is_required=True)
def get_patient_summary(patient_name: str, client_name: str, species: str) -> dict:
    """Retrieve a (randomised) consolidated clinical summary for a patient: recent
    visit history, vaccination/microchip status, and any upcoming appointment."""
    logging.info(f"get_patient_summary called for {patient_name} ({species}), client {client_name}")

    num_visits = random.randint(1, 5)
    visits = []
    for _ in range(num_visits):
        visit_date = _random_past_datetime()
        visits.append(
            {
                "visit_id": str(uuid.uuid4()),
                "date": visit_date.strftime("%Y-%m-%d"),
                "vet": random.choice(_VET_NAMES),
                "reason": random.choice(_VISIT_REASONS),
                "diagnosis": random.choice(_DIAGNOSES),
                "weight_kg": round(random.uniform(2.0, 45.0), 1),
                "temperature_c": round(random.uniform(37.5, 39.5), 1),
            }
        )
    visits.sort(key=lambda v: v["date"], reverse=True)

    vaccinations = _random_vaccination_status()

    upcoming_appointment = None
    if random.random() >= 0.1:
        appointment_dt = _random_future_datetime()
        upcoming_appointment = {
            "appointment_id": str(uuid.uuid4()),
            "date": appointment_dt.strftime("%Y-%m-%d"),
            "time": appointment_dt.strftime("%H:%M"),
            "vet": random.choice(_VET_NAMES),
            "reason": random.choice(_VISIT_REASONS),
            "location": random.choice(_CLINIC_LOCATIONS),
        }

    return {
        "patient_name": patient_name,
        "client_name": client_name,
        "species": species,
        "microchip_status": random.choice(["registered", "not registered", "registration pending"]),
        "visit_count": num_visits,
        "recent_visits": visits,
        "vaccinations": vaccinations,
        "has_upcoming_appointment": upcoming_appointment is not None,
        "upcoming_appointment": upcoming_appointment,
    }


# ---------------------------------------------------------------------------
# Tool 2: schedule_appointment
# ---------------------------------------------------------------------------

@app.mcp_tool()
@app.mcp_tool_property(arg_name="patient_name", description="The name of the animal patient.", is_required=True)
@app.mcp_tool_property(arg_name="client_name", description="The name of the client (the patient's owner).", is_required=True)
@app.mcp_tool_property(arg_name="species", description="The species of the patient, e.g. dog, cat, rabbit.", is_required=True)
@app.mcp_tool_property(arg_name="reason", description="The reason for the appointment, e.g. 'Annual wellness check' or 'Limping / lameness assessment'.", is_required=True)
@app.mcp_tool_property(arg_name="preferred_date", description="Preferred appointment date in YYYY-MM-DD format. If omitted, or unavailable, the next available slot is offered instead.", is_required=False)
@app.mcp_tool_property(arg_name="location", description="Preferred clinic location, e.g. 'Riverside Veterinary Clinic - Main St'. Defaults to the nearest/any available clinic if omitted.", is_required=False)
def schedule_appointment(
    patient_name: str,
    client_name: str,
    species: str,
    reason: str,
    preferred_date: str = None,
    location: str = None,
) -> dict:
    """Book a (simulated) veterinary appointment for a patient and return a confirmation."""
    logging.info(
        f"schedule_appointment called for {patient_name} ({species}), client {client_name}, "
        f"reason={reason}, preferred_date={preferred_date}, location={location}"
    )

    resolved_location = location or random.choice(_CLINIC_LOCATIONS)

    requested_date = None
    if preferred_date:
        try:
            requested_date = datetime.strptime(preferred_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            requested_date = None

    # Small chance the preferred date is unavailable and an alternative slot is offered.
    slot_available = requested_date is not None and random.random() >= 0.3

    if slot_available:
        confirmed_dt = requested_date.replace(
            hour=random.choice([9, 10, 11, 13, 14, 15, 16]),
            minute=random.choice([0, 15, 30, 45]),
        )
        rescheduled = False
    else:
        confirmed_dt = _random_future_datetime()
        rescheduled = requested_date is not None

    return {
        "patient_name": patient_name,
        "client_name": client_name,
        "species": species,
        "reason": reason,
        "status": "confirmed",
        "appointment_id": str(uuid.uuid4()),
        "date": confirmed_dt.strftime("%Y-%m-%d"),
        "time": confirmed_dt.strftime("%H:%M"),
        "vet": random.choice(_VET_NAMES),
        "location": resolved_location,
        "preferred_date_honoured": not rescheduled,
        "message": (
            f"Requested date unavailable; booked next available slot on {confirmed_dt.strftime('%Y-%m-%d')} "
            f"at {confirmed_dt.strftime('%H:%M')}."
            if rescheduled
            else f"Appointment confirmed for {confirmed_dt.strftime('%Y-%m-%d')} at {confirmed_dt.strftime('%H:%M')}."
        ),
    }


# ---------------------------------------------------------------------------
# Tool 3: order_stock
# ---------------------------------------------------------------------------

@app.mcp_tool()
@app.mcp_tool_property(arg_name="medicine_name", description="The name of the veterinary medicine to check/order, e.g. Amoxicillin.", is_required=True)
@app.mcp_tool_property(arg_name="location", description="The clinic location to check/order stock for, e.g. 'Riverside Veterinary Clinic - Main St'.", is_required=False)
@app.mcp_tool_property(arg_name="quantity_to_order", description="Quantity of the medicine to order, if placing an order. Omit or set to 0 to only check stock.", is_required=False)
def order_stock(medicine_name: str, location: str = None, quantity_to_order: int = 0) -> dict:
    """Check current stock level of a veterinary medicine at a clinic location, and optionally place an order to top it up."""
    logging.info(f"order_stock called for {medicine_name} at {location}, quantity_to_order={quantity_to_order}")

    try:
        request = OrderStockRequest(
            medicine_name=medicine_name,
            location=location,
            quantity_to_order=quantity_to_order,
        )
    except ValidationError as exc:
        validation_errors = exc.errors()
        first_error = validation_errors[0] if validation_errors else None
        field_name = first_error["loc"][0] if first_error and first_error.get("loc") else "input"

        if field_name == "medicine_name":
            message = "Unknown medicine_name. Please use one of the supported medicine names."
        elif field_name == "quantity_to_order":
            message = "quantity_to_order must be a non-negative integer."
        else:
            message = "Invalid input for order_stock. Please check the provided arguments."

        return {
            "medicine_name": medicine_name,
            "category": None,
            "location": location or random.choice(_CLINIC_LOCATIONS),
            "current_stock_units": None,
            "low_stock": None,
            "reorder_threshold": None,
            "order": {
                "status": "not_requested",
                "order_id": None,
                "quantity_ordered": 0,
                "estimated_delivery_date": None,
                "projected_stock_after_delivery": None,
            },
            "allowed_medicines": [m.value for m in MedicineName],
            "message": message,
        }

    resolved_location = request.location or random.choice(_CLINIC_LOCATIONS)
    medicine_name = request.medicine_name.value
    quantity_to_order = request.quantity_to_order
    category = _MEDICATIONS[request.medicine_name]

    current_stock = random.randint(0, 200)
    reorder_threshold = 25
    low_stock = current_stock < reorder_threshold

    response = {
        "medicine_name": medicine_name,
        "category": category,
        "location": resolved_location,
        "current_stock_units": current_stock,
        "low_stock": low_stock,
        "reorder_threshold": reorder_threshold,
    }

    # The "order" object always has the same shape regardless of whether an
    # order was placed, so callers/agents can rely on a stable schema rather
    # than branching on whether the field is null vs. populated.
    if quantity_to_order and quantity_to_order > 0:
        eta_days = random.randint(1, 7)
        eta_date = (datetime.now(timezone.utc) + timedelta(days=eta_days)).strftime("%Y-%m-%d")
        response["order"] = {
            "status": "placed",
            "order_id": str(uuid.uuid4()),
            "quantity_ordered": quantity_to_order,
            "estimated_delivery_date": eta_date,
            "projected_stock_after_delivery": current_stock + quantity_to_order,
        }
        response["message"] = (
            f"Order placed for {quantity_to_order} unit(s) of {medicine_name} "
            f"at {resolved_location}. Estimated delivery: {eta_date}."
        )
    else:
        response["order"] = {
            "status": "not_requested",
            "order_id": None,
            "quantity_ordered": 0,
            "estimated_delivery_date": None,
            "projected_stock_after_delivery": current_stock,
        }
        if low_stock:
            response["message"] = (
                f"Stock is low ({current_stock} units) at {resolved_location}. "
                "Consider ordering more by supplying a 'quantity_to_order' value."
            )
        else:
            response["message"] = (
                f"{medicine_name} currently has {current_stock} units in stock at {resolved_location}."
            )

    return response
