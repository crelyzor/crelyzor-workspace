# Phase 3.4 — Global Tags (Contact Tags Backend)

## What was built
As part of Phase 3.4 to make tags truly global (spanning Meetings, Cards, Tasks, and Contacts), we implemented the backend schema and APIs for assigning tags to Card Contacts.

### Database Schema Updates
- Added `ContactTag` junction model to `schema.prisma` with a composite primary key (`contactId`, `tagId`).
- Both relationships (`contact` and `tag`) use `onDelete: Cascade` to ensure proper cleanup if a contact or tag is hard-deleted.
- Added the `contactTags` array relation on the `CardContact` and `Tag` models.
- Updated the `deleteTag` transactional method in `tagService.ts` to also delete from the `ContactTag` table when a tag is deleted, ensuring no orphaned junctions exist.

### Backend APIs
Created a new set of APIs under `cardRoutes.ts` specifically for managing tags on a Card's Contact:
- `GET /api/v1/cards/:cardId/contacts/:contactId/tags` — Fetches tags assigned to a specific contact.
- `POST /api/v1/cards/:cardId/contacts/:contactId/tags/:tagId` — Attaches a tag to a contact.
- `DELETE /api/v1/cards/:cardId/contacts/:contactId/tags/:tagId` — Detaches a tag from a contact.

Zod param schemas (`contactIdParamSchema`, `tagContactParamSchema`) were added to strictly validate `uuid` formats in `tagSchema.ts`.

## Patterns used
- Followed the established pattern of separating the "ownership verification" and the actual repository-level logic in `tagService.ts` (e.g., `verifyContactOwnership`).
- Validation at the API edge via existing controller Zod param parsing.
- Used `upsert` when attaching tags to avoid race conditions or duplicates (`contactId_tagId` composite key).
- Used `deleteMany` for detach endpoint for clean removal.
- Ensured fail-open routing and consistent response handlers via `apiResponse`.

## Gotchas & Tricky Parts
- **Naming Clashes & Back-references**: `CardContact` already had a legacy `tags String[]` array intended for free-text storage. To avoid conflicts and prevent data loss, we named the new Relation field `contactTags ContactTag[]`. We briefly tried renaming the `card` relation to `cardRel`, but reverted to `card` to avoid breaking downstream schema references (kept `card` and simply named the new relation `contactTags`).
- **Authorization Traversal**: Validating whether a user owns a contact requires going through the associated card. Implemented this in `tagService.ts`: `CardContact -> card -> userId` must equal the JWT's `userId`.

## Decisions made (and why)
- **Leaving `tags String[]` intact**: The legacy `tags` field in `CardContact` was not removed or migrated yet. It allows the new tag linking to coexist without having to write immediate data migration scripts, reducing the impact on current usage.
