"""
Pet Insurance MCP Server (Azure Functions, Python)

Exposes four MCP tools for a pet insurance workflow:
  1. check_coverage         - returns a simulated coverage summary for a service
  2. request_pre_auth       - requests pre-authorization for an estimated treatment cost
  3. check_claim_status     - retrieves a simulated claim status update
  4. submit_claim_documents - submits claim supporting documents and returns receipt details

This is a scaffold: all data is generated randomly in-memory to simulate an
insurance platform backend. Replace the helper functions with real claims and
policy-system integrations when wiring to production services.
"""

import logging
import random
import uuid
from datetime import datetime, timedelta, timezone
from enum import Enum

import azure.functions as func
from pydantic import BaseModel, Field, ValidationError, field_validator

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


_POLICY_STATUSES = ["active", "active with exclusions", "lapsed", "pending renewal"]
_SERVICE_TYPES = [
    "annual wellness visit",
    "urgent care visit",
    "diagnostic imaging",
    "dental procedure",
    "orthopedic surgery",
    "prescription medication",
    "specialist referral",
    "emergency admission",
]
_COVERAGE_TYPES = [
    "accident only",
    "accident and illness",
    "wellness rider",
    "dental rider",
    "hereditary condition exclusion",
]
_CLAIM_STATUSES = [
    "submitted",
    "in review",
    "documents required",
    "approved",
    "denied",
    "paid",
]


class CoverageRequest(BaseModel):
    policy_number: str
    pet_name: str
    service_type: str


class PreAuthRequest(BaseModel):
    policy_number: str
    pet_name: str
    service_type: str
    estimated_cost: float = Field(gt=0)


class ClaimStatusRequest(BaseModel):
    claim_number: str


class ClaimDocumentSubmissionRequest(BaseModel):
    claim_number: str
    documents: str
    source: str | None = None


def _random_past_datetime(max_days_back: int = 365) -> datetime:
    days_back = random.randint(1, max_days_back)
    return datetime.now(timezone.utc) - timedelta(days=days_back)


def _random_future_datetime(max_days_forward: int = 30) -> datetime:
    days_forward = random.randint(1, max_days_forward)
    return datetime.now(timezone.utc) + timedelta(days=days_forward)


def _split_documents(documents: str) -> list[str]:
    return [document.strip() for document in documents.split(",") if document.strip()]


# ---------------------------------------------------------------------------
# Tool 1: check_coverage
# ---------------------------------------------------------------------------

@app.mcp_tool()
@app.mcp_tool_property(arg_name="policy_number", description="The pet insurance policy number.", is_required=True)
@app.mcp_tool_property(arg_name="pet_name", description="The name of the insured pet.", is_required=True)
@app.mcp_tool_property(arg_name="service_type", description="The service to check coverage for, e.g. 'dental procedure' or 'urgent care visit'.", is_required=True)
def check_coverage(policy_number: str, pet_name: str, service_type: str) -> dict:
    """Return a simulated coverage summary for a policy and requested service."""
    logging.info(f"check_coverage called for {pet_name}, policy={policy_number}, service_type={service_type}")

    policy_status = random.choice(_POLICY_STATUSES)
    coverage_type = random.choice(_COVERAGE_TYPES)
    covered = policy_status.startswith("active") and random.random() >= 0.2
    coverage_percentage = random.choice([50, 70, 80, 90]) if covered else 0
    deductible_remaining = round(random.uniform(0, 750), 2) if covered else None
    copay_percentage = 100 - coverage_percentage if covered else None
    annual_limit_remaining = round(random.uniform(200, 5000), 2) if covered else 0.0

    return {
        "policy_number": policy_number,
        "pet_name": pet_name,
        "service_type": service_type,
        "policy_status": policy_status,
        "coverage_type": coverage_type,
        "covered": covered,
        "coverage_percentage": coverage_percentage,
        "deductible_remaining": deductible_remaining,
        "copay_percentage": copay_percentage,
        "annual_limit_remaining": annual_limit_remaining,
        "message": (
            f"{service_type.title()} is covered under policy {policy_number}."
            if covered
            else f"{service_type.title()} is not currently covered under policy {policy_number}."
        ),
    }


# ---------------------------------------------------------------------------
# Tool 2: request_pre_auth
# ---------------------------------------------------------------------------

@app.mcp_tool()
@app.mcp_tool_property(arg_name="policy_number", description="The pet insurance policy number.", is_required=True)
@app.mcp_tool_property(arg_name="pet_name", description="The name of the insured pet.", is_required=True)
@app.mcp_tool_property(arg_name="service_type", description="The treatment or service requiring pre-authorization.", is_required=True)
@app.mcp_tool_property(arg_name="estimated_cost", description="Estimated treatment cost in local currency.", is_required=True)
def request_pre_auth(policy_number: str, pet_name: str, service_type: str, estimated_cost: float) -> dict:
    """Simulate a pre-authorization request and return a decision."""
    logging.info(
        f"request_pre_auth called for {pet_name}, policy={policy_number}, service_type={service_type}, estimated_cost={estimated_cost}"
    )

    try:
        request = PreAuthRequest(
            policy_number=policy_number,
            pet_name=pet_name,
            service_type=service_type,
            estimated_cost=estimated_cost,
        )
    except ValidationError as exc:
        first_error = exc.errors()[0] if exc.errors() else None
        return {
            "policy_number": policy_number,
            "pet_name": pet_name,
            "service_type": service_type,
            "estimated_cost": estimated_cost,
            "status": "not_requested",
            "preauth_id": None,
            "approved_amount": None,
            "expires_on": None,
            "message": f"Invalid pre-auth request: {first_error['msg'] if first_error else 'check the provided arguments' }",
        }

    approved = random.random() >= 0.25 and estimated_cost <= 7500
    response = {
        "policy_number": request.policy_number,
        "pet_name": request.pet_name,
        "service_type": request.service_type,
        "estimated_cost": request.estimated_cost,
        "status": "approved" if approved else "pending review",
        "preauth_id": str(uuid.uuid4()),
        "approved_amount": round(request.estimated_cost * random.uniform(0.6, 1.0), 2) if approved else None,
        "expires_on": (_random_future_datetime(max_days_forward=45)).strftime("%Y-%m-%d") if approved else None,
    }
    response["message"] = (
        f"Pre-authorization approved for {request.service_type} at {response['approved_amount']:.2f}."
        if approved
        else f"Pre-authorization for {request.service_type} has been queued for manual review."
    )
    return response


# ---------------------------------------------------------------------------
# Tool 3: check_claim_status
# ---------------------------------------------------------------------------

@app.mcp_tool()
@app.mcp_tool_property(arg_name="claim_number", description="The pet insurance claim number.", is_required=True)
def check_claim_status(claim_number: str) -> dict:
    """Return a simulated status for an existing claim."""
    logging.info(f"check_claim_status called for claim={claim_number}")

    status = random.choice(_CLAIM_STATUSES)
    submitted_at = _random_past_datetime(max_days_back=90)
    last_updated = submitted_at + timedelta(days=random.randint(0, 14))
    amount_claimed = round(random.uniform(75, 4500), 2)
    amount_paid = round(amount_claimed * random.uniform(0.0, 1.0), 2) if status in {"approved", "paid"} else 0.0

    return {
        "claim_number": claim_number,
        "status": status,
        "submitted_at": submitted_at.strftime("%Y-%m-%d"),
        "last_updated": last_updated.strftime("%Y-%m-%d"),
        "amount_claimed": amount_claimed,
        "amount_paid": amount_paid,
        "documents_received": random.choice([True, False]),
        "next_step": (
            "Awaiting adjuster review"
            if status in {"submitted", "in review"}
            else "Additional documents required"
            if status == "documents required"
            else "No further action needed"
        ),
    }


# ---------------------------------------------------------------------------
# Tool 4: submit_claim_documents
# ---------------------------------------------------------------------------

@app.mcp_tool()
@app.mcp_tool_property(arg_name="claim_number", description="The pet insurance claim number.", is_required=True)
@app.mcp_tool_property(arg_name="documents", description="Comma-separated document names, for example 'invoice.pdf, receipt.jpg, referral-letter.pdf'.", is_required=True)
@app.mcp_tool_property(arg_name="source", description="Optional submission source, such as a clinic or portal name.", is_required=False)
def submit_claim_documents(claim_number: str, documents: str, source: str | None = None) -> dict:
    """Simulate uploading supporting claim documents and return a submission receipt."""
    logging.info(f"submit_claim_documents called for claim={claim_number}, source={source}")

    try:
        request = ClaimDocumentSubmissionRequest(
            claim_number=claim_number,
            documents=documents,
            source=source,
        )
    except ValidationError as exc:
        first_error = exc.errors()[0] if exc.errors() else None
        return {
            "claim_number": claim_number,
            "submission_id": None,
            "status": "not_submitted",
            "documents": [],
            "document_count": 0,
            "source": source,
            "received_at": None,
            "message": f"Invalid document submission: {first_error['msg'] if first_error else 'check the provided arguments'}",
        }

    submitted_documents = _split_documents(request.documents)
    received_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "claim_number": request.claim_number,
        "submission_id": str(uuid.uuid4()),
        "status": "received",
        "documents": submitted_documents,
        "document_count": len(submitted_documents),
        "source": request.source or "manual upload",
        "received_at": received_at,
        "expected_review_window_days": random.randint(2, 7),
        "message": (
            f"Received {len(submitted_documents)} document(s) for claim {request.claim_number}."
        ),
    }
