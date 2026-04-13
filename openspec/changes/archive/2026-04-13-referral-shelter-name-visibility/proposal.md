## Why

Outreach workers currently see only population types in the "My Referrals" section (e.g., "DV_SURVIVOR — 2 persons"). This makes it impossible to distinguish between multiple pending referrals to different shelters or for different households of the same type without clicking into details. Adding the shelter name and a time-based identifier (e.g., "Safe Haven — 2:15 PM") provides essential operational context for workers (Darius) managing multiple placements in high-pressure field environments.

## What Changes

- **Database**: Add a `shelter_name` column to the `referral_token` table to snapshot the name at creation time.
- **Backend Logic**: Update `ReferralTokenService.createToken` to capture and store the shelter name. Implement a "Safety Check" on retrieval to flag referrals for shelters that have since been deactivated.
- **API**: Update the `ReferralTokenResponse` DTO to include `shelterName` and ensure `createdAt` is used for worker-facing identifiers.
- **Frontend**: Update the "My Referrals" list in `OutreachSearch.tsx` to display the shelter name and a time suffix.
- **Accessibility**: Implement structured `aria-labels` that prioritize status while providing name and time context (Tomás persona).
- **Security**: Ensure snapshotted shelter names are cleared from the frontend cache upon logout (Elena persona).

## Capabilities

### Modified Capabilities
- `dv-referral-token`: Update requirements to include shelter name snapshots, safety checks, and enhanced list identifiers.

## Impact

- **Backend**: `ReferralToken` domain model, `ReferralTokenRepository`, `ReferralTokenService`, and `ReferralTokenResponse` DTO.
- **Frontend**: `ReferralToken` interface and list rendering in `OutreachSearch.tsx`.
- **Database**: Schema migration `V51`.
