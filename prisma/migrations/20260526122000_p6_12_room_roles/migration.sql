-- P6.12 Room roles — delegated per-room moderation.
--
-- A room owner can promote trusted members to room MODERATOR without
-- granting the heavyweight global MODERATOR role. The room owner stays
-- `rooms.owner_id`; this table only ever holds room-scoped grants, so
-- it is structurally impossible to escalate to a global role through
-- it. `revoked_at` soft-revokes a grant (the row survives for audit).

CREATE TABLE "room_roles" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" TEXT NOT NULL,
    "granted_by" UUID,
    "granted_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revoked_at" TIMESTAMPTZ(6),

    CONSTRAINT "room_roles_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "room_roles_room_id_user_id_key"
    ON "room_roles"("room_id", "user_id");

CREATE INDEX "room_roles_room_id_revoked_at_idx"
    ON "room_roles"("room_id", "revoked_at");

ALTER TABLE "room_roles" ADD CONSTRAINT "room_roles_room_id_fkey"
    FOREIGN KEY ("room_id") REFERENCES "rooms"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "room_roles" ADD CONSTRAINT "room_roles_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Granter is nullable + SET NULL so deleting the granting user doesn't
-- cascade-delete the grant (the moderator stays; we just lose the
-- "granted by" attribution).
ALTER TABLE "room_roles" ADD CONSTRAINT "room_roles_granted_by_fkey"
    FOREIGN KEY ("granted_by") REFERENCES "users"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
