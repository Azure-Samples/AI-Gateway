"""Helpers used only during execution of the Web IQ Jupyter notebooks.

Imported by web-iq.ipynb and web-iq-mcp-responses.ipynb to read and format
gateway moderation telemetry from REST and MCP results for display.
This module is not part of the deployed gateway runtime. APIM performs
content moderation and blocking through the content-safety-outbound.xml policy.
"""

import json
import re


CATEGORIES = ('Hate', 'Sexual', 'Violence', 'SelfHarm')


def extract_content_safety(value):
    """Read JSON, MCP metadata, structured content, or moderation in tool text."""
    if isinstance(value, str):
        try:
            return extract_content_safety(json.loads(value))
        except (ValueError, TypeError):
            # Some MCP clients concatenate text blocks instead of returning a JSON array.
            matches = list(re.finditer(r'\{\s*"contentSafety"\s*:', value))
            for match in reversed(matches):
                try:
                    item, _ = json.JSONDecoder().raw_decode(value, match.start())
                except ValueError:
                    continue
                telemetry = extract_content_safety(item)
                if telemetry is not None:
                    return telemetry
    elif isinstance(value, dict):
        telemetry = value.get('contentSafety')
        if isinstance(telemetry, dict) and 'status' in telemetry:
            return telemetry
        for key in ('_meta', 'result', 'error', 'data', 'structuredContent', 'content', 'output', 'text'):
            telemetry = extract_content_safety(value.get(key))
            if telemetry is not None:
                return telemetry
    elif isinstance(value, list):
        for item in reversed(value):
            telemetry = extract_content_safety(item)
            if telemetry is not None:
                return telemetry
    return None


def content_safety_from_response(response):
    """Prefer gateway headers; fall back to body telemetry for saved results."""
    status = response.headers.get('x-content-safety-status')
    if status:
        return {
            'status': status,
            'scores': json.loads(response.headers.get('x-content-safety-scores', '{}')),
            'chunks': response.headers.get('x-content-safety-chunks'),
            'latencyMs': response.headers.get('x-content-safety-latency-ms'),
            'requestId': response.headers.get('x-apim-request-id'),
        }
    try:
        return extract_content_safety(response.json())
    except ValueError:
        return None


def content_safety_row(telemetry):
    """Flatten the four category scores without treating missing scores as zero."""
    telemetry = telemetry or {}
    scores = telemetry.get('scores') or {}
    return {
        'safety_status': telemetry.get('status', 'missing'),
        **{category: scores.get(category) for category in CATEGORIES},
        'safety_chunks': telemetry.get('chunks'),
        'safety_latency_ms': telemetry.get('latencyMs'),
        'request_id': telemetry.get('requestId'),
    }
