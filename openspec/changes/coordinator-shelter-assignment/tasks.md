## Tasks

### Setup

- [ ] T-0: Create branch `feature/coordinator-shelter-assignment` from main

### Backend — User Shelters API

- [ ] T-1: `GET /api/v1/users/{id}/shelters` — returns list of `{id, name}` for shelters assigned to the user. Uses `CoordinatorAssignmentRepository.findShelterIdsByUserId()` + shelter name lookup. Requires COC_ADMIN or PLATFORM_ADMIN role.
- [ ] T-2: Integration test: coordinator with 2 assigned shelters → returns 2 shelter objects
- [ ] T-3: Integration test: user with no assignments → returns empty array

### Frontend — Shelter Edit: Assigned Coordinators (Primary)

- [ ] T-4: Create `CoordinatorCombobox` component: searchable text input, filtered dropdown of eligible users (COORDINATOR + COC_ADMIN roles), removable chips for selected coordinators. Follows W3C APG Combobox Pattern (role="combobox", aria-haspopup="listbox", aria-activedescendant, keyboard arrows/enter/escape).
- [ ] T-5: Fetch eligible coordinators on mount: `GET /api/v1/users` filtered client-side to COORDINATOR/COC_ADMIN roles. Display name + email in dropdown items.
- [ ] T-6: For DV shelters: indicate dvAccess status in dropdown (e.g., badge or icon). Show warning on non-dvAccess users: "Won't receive DV referral notifications."
- [ ] T-7: Integrate into `ShelterForm.tsx` after capacities section. Load current assignments on mount via existing shelter data or separate API call.
- [ ] T-8: On shelter save: diff staged chips vs original assignments. Call `POST /shelters/{id}/coordinators` for additions, `DELETE /shelters/{id}/coordinators/{userId}` for removals.
- [ ] T-9: Chip styling: use existing color tokens (color.bg, color.text, color.border, color.primaryText), min 44px touch target on remove buttons, dark mode via CSS custom properties.
- [ ] T-10: i18n: "Assigned Coordinators", "Search coordinators...", "No coordinators assigned", "Remove {name}", "Won't receive DV referral notifications" (en + es)

### Frontend — User Edit: Assigned Shelters (Read-Only)

- [ ] T-11: Add "Assigned Shelters" section to `UserEditDrawer.tsx` after dvAccess checkbox. Fetch from `GET /api/v1/users/{id}/shelters` on drawer open.
- [ ] T-12: Display shelter names as read-only chips (no remove button). Each chip links to `/coordinator/shelters/{id}/edit?from=/admin`.
- [ ] T-13: Show "No shelters assigned" when list is empty. Use color.textMuted for empty state text.
- [ ] T-14: i18n: "Assigned Shelters", "No shelters assigned" (en + es)

### Frontend — Tests

- [ ] T-15: Playwright: admin opens shelter edit → "Assigned Coordinators" section visible with combobox
- [ ] T-16: Playwright: admin types coordinator name → dropdown filters → select adds chip
- [ ] T-17: Playwright: admin removes chip → chip disappears (staged, not persisted)
- [ ] T-18: Playwright: admin saves shelter → assignment persisted (verify via API)
- [ ] T-19: Playwright: admin opens user edit drawer → "Assigned Shelters" chips visible
- [ ] T-20: Playwright: WCAG — combobox has role="combobox", chips have aria-label, keyboard navigation works

### Documentation

- [ ] T-21: Update docs/FOR-DEVELOPERS.md — add `GET /api/v1/users/{id}/shelters` endpoint
- [ ] T-22: Update docs/asyncapi.yaml — if assignment events are needed (defer if not)

### Verification

- [ ] T-23: npm run build — zero errors
- [ ] T-24: ESLint clean
- [ ] T-25: Full backend test suite — all green
- [ ] T-26: Full Playwright suite through nginx — all green
- [ ] T-27: Merge to main, tag, release, deploy
