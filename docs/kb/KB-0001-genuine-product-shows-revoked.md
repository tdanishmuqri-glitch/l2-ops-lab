# KB-0001 — Customer reports a genuine product shows "revoked"

**Audience:** L1 (steps 1–3), L2 (steps 4–6) · **Category:** Verification result

## Symptom
Consumer scans a product they bought from an authorised store; the app says **revoked** (not "unknown").

## Cause
"Revoked" means the code exists but the brand owner deactivated it (recall, stolen batch, or data-load error). It is *not* a system fault.

## Resolution
1. Ask for: the code, photo of the label, country, time of scan.
2. Reproduce: `POST /verify {"code": "<code>"}` (Postman "Verify - revoked").
3. If result is `revoked` → this is a data question, not an outage. Escalate to L2 with code + evidence.
4. L2: run query 1 and 2 in `sql/troubleshooting_queries.sql` to confirm status and when the result changed.
5. If the brand owner confirms revocation was an error → raise a **service request** for the status change (query 8, in a transaction, with approval reference in the ticket).
6. Reply to customer; close with the brand owner's reference.

**Do not** change a code's status without written approval from the brand owner.
