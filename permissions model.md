# Permissions Model — v1.0

This document provides a structured, implementable permissions model for the project. It contains:
- Role definitions
- Resources and actions
- A role-capability matrix
- Example Firestore schema fields
- Firestore Security Rules examples
- Server-side enforcement guidance (Cloud Functions)
- Frontend (Flutter) implementation guidance
- Migration and testing checklist

**Goals:**
- Keep authorization simple and auditable.
- Enforce minimum privilege: users get only the permissions they need.
- Ensure security is enforced server-side (Firestore rules + server checks) and mirrored in the UI.

---

## Roles (recommended)

- **Super Admin**: Full access to all projects, teams, and global settings (highest privilege).
- **HR**: Global HR responsibilities: manage users, view/download attendance, create teams, create projects, view all tasks across teams.
- **Admin**: Project-level admin: create/update/delete projects for their project(s), manage team membership, manage tasks and inventory.
- **Manager**: Can create/edit tasks, assign tasks to team members, update statuses, and view reports for their teams.
- **Monitor**: Read access to team tasks, can update some fields like status or due date if designated.
- **Member**: Regular team member; can view tasks assigned to them, update status/comments on tasks they are assigned to.
- **Guest** (optional): Read-only limited access (e.g., view reports without sensitive fields).

Notes:
- Roles can be global or scoped to a team/project. For simple systems, prefer team-scoped roles where a user may have different roles across teams.

---

## Resources & Actions

Common resources and recommended actions:

- Projects: create, read, update, delete, assignUsers
- Teams: create, read, update, delete, addMember, removeMember
- Tasks: create, read, update, delete, assign, comment, changeStatus
- Inventory: create, read, update, delete
- Reports: read, generate, download
- Attendance: mark, read, download
- Documents: upload, read, update, delete

---

## Role → Capability Matrix (summary)

Use this matrix to map which role can perform which high-level action. Implement as a server-side policy or as fields in the `roles` collection.

- Super Admin: all actions on all resources
- HR: Projects(read/create), Teams(create/read), Users(manage), Attendance(all)
- Admin: Projects(full for assigned projects), Teams(full for assigned teams), Tasks(full), Inventory(full)
- Manager: Tasks(create/update/assign within team), Reports(read/generate for team), Members(view)
- Monitor: Tasks(read for team, limited updates if allowed), Reports(view)
- Member: Tasks(read for assigned tasks, update status/comment on assigned tasks), Documents(read
- Guest: Read-only on select resources

Represent this matrix in code as a mapping object, e.g. `Map<Role, Set<Action>>` or store role-documents in Firestore.

---

## Firestore Data Model (recommended fields)

Keep a minimal, explicit structure so rules are easy to write.

- `users/{userId}`:
   - `displayName`, `email`, ...
   - `roles`: map of `teamId -> roleName` (e.g., `{ "team_abc": "manager", "global": "hr" }`)
   - `globalRoles`: array of roles that are global (e.g., `["hr"]`)

- `teams/{teamId}`:
   - `name`, `projectId`, `createdAt`, `members`: array of userIds (optional: map of userId->role)

- `projects/{projectId}`:
   - `name`, `ownerId`, `teamIds` ...

- `tasks/{taskId}`:
   - `id`, `title`, `description`, `assignedTeamId` (must be teamId!),
   - `assignedTo`: array of userIds,
   - `monitors`: array of userIds,
   - `createdBy`, `status`, `priority`, `dueDate`, `createdAt`, `updatedAt`

Important: ensure `assignedTeamId` is set for each task (empty string will cause team queries to fail).

---

## Firestore Security Rules — Examples

Below are illustrative rules. Adapt them to your exact collection names, indexing needs, and app structure.

Rules assumptions:
- `request.auth.uid` is the authenticated user's uid
- `getUserRole(uid, teamId)` is a helper pattern (we implement inline using `get()` or user roles stored under `users/{uid}.roles`)

Example (simplified):

```rules
rules_version = '2';
service cloud.firestore {
   match /databases/{database}/documents {

      // Users: allow user to read/write their own profile
      match /users/{userId} {
         allow read: if request.auth != null;
         allow write: if request.auth != null && request.auth.uid == userId;
      }

      // Tasks
      match /tasks/{taskId} {
         allow read: if isMemberOfTeamOrAssigned() || hasGlobalRole('hr') || isSuperAdmin();
         allow create: if canCreateTask();
         allow update: if canUpdateTask();
         allow delete: if canDeleteTask();

         function isSuperAdmin() {
            return exists(/databases/$(database)/documents/users/$(request.auth.uid))
               && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.globalRoles.hasAny(['super_admin']);
         }

         function hasGlobalRole(role) {
            return request.auth != null &&
               get(/databases/$(database)/documents/users/$(request.auth.uid)).data.globalRoles.hasAny([role]);
         }

         function getUserRoleForTeam(teamId) {
            if (request.auth == null) return null;
            let roles = get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles;
            return roles[teamId];
         }

         function isMemberOfTeamOrAssigned() {
            if (request.auth == null) return false;
            let teamId = resource.data.assignedTeamId;
            // Check assignedTo or monitors
            return resource.data.assignedTo.hasAny([request.auth.uid]) ||
                      resource.data.monitors.hasAny([request.auth.uid]) ||
                      (teamId != null && getUserRoleForTeam(teamId) != null);
         }

         function canCreateTask() {
            if (request.auth == null) return false;
            // Only managers/admin/hr for the team can create tasks
            let teamId = request.resource.data.assignedTeamId;
            let role = getUserRoleForTeam(teamId);
            return role in ['manager','admin'] || hasGlobalRole('hr') || isSuperAdmin();
         }

         function canUpdateTask() {
            if (request.auth == null) return false;
            // Allow assigned user to update allowed fields (status/comments) OR managers/admins to update
            let role = getUserRoleForTeam(resource.data.assignedTeamId);
            return resource.data.assignedTo.hasAny([request.auth.uid]) || role in ['manager','admin'] || hasGlobalRole('hr') || isSuperAdmin();
         }

         function canDeleteTask() {
            if (request.auth == null) return false;
            let role = getUserRoleForTeam(resource.data.assignedTeamId);
            return role in ['admin'] || hasGlobalRole('hr') || isSuperAdmin();
         }
      }

   }
}
```

Notes:
- Rules must be tested in the Firebase emulator before production.
- Keep rule functions small; complex logic is easier to reason about on server-side (Cloud Functions).

---

## Server-side enforcement (Cloud Functions / backend APIs)

- Use Cloud Functions for operations that must be trusted (e.g., sending notifications, complex multi-document updates, audit logging).
- Validate that `assignedTeamId` equals the team used for membership checks before creating tasks.
- Use a server-side role lookup (fetch `users/{uid}.roles`) when performing sensitive operations.
- Keep a consistent helper library for permission checks so both Cloud Functions and any backend APIs call the same logic.

---

## Frontend (Flutter) implementation guidance

- Do not rely on UI-only checks for security. Always handle denial gracefully (show permission error when server rejects).
- Mirror server roles in client state to control visibility. Example:
   - Show `Create Task` FAB only when user role is `manager|admin|hr` for the current team.
   - Hide assignment UI when the current user lacks permission to assign.
- Implement route guards for pages that require certain roles. Example: report generation pages accessible only to `manager|admin|hr`.
- On actions that may be rejected by server rules, handle `PERMISSION_DENIED` errors with an explanatory Snackbar and log audit events.

Example Flutter patterns:
- Provide a `CurrentUser` provider that exposes `uid`, `globalRoles`, and `rolesByTeam`.
- Create a `Permission` helper: `bool can(String action, {String teamId})` which checks cached roles and optionally verifies with server.

---

## Data migration notes (urgent actions)

Problems seen in your data (from inspection): some tasks have `assignedTeamId` set to an empty string. This will prevent team-scoped queries from returning those tasks.

Migration steps:
1. Back up `tasks` collection (export) before changes.
2. Identify tasks with empty `assignedTeamId`:
    - Query: `where('assignedTeamId', '==', '')` or where the field is missing.
3. Determine the correct `teamId` for each task. If impossible to determine programmatically, flag for manual review.
4. Write a Cloud Function / script to update `assignedTeamId` for affected tasks.
5. Re-run client tests and security rule emulator tests.

---

## Testing checklist

- Run Firestore rules unit tests using the Firebase emulator.
- Test common scenarios: member viewing assigned task, manager creating tasks, HR viewing all.
- Test negative scenarios: member cannot delete unassigned task, non-HR cannot change global attendance.
- Test UI flows: Fab visibility, disabled controls, proper error messages on denied writes.

---

## Example small role JSON (stored in `users/{uid}.roles`)

```json
{
   "globalRoles": ["hr"],
   "roles": {
      "team_abc": "manager",
      "team_xyz": "member"
   }
}
```

---

## Next steps & recommendations

1. Migrate the `assignedTeamId` values for tasks that have empty values.
2. Add the `roles` structure to each `users/{uid}` if not present.
3. Implement Firestore rules using the examples above and test using the emulator.
4. Add a small permission helper in Flutter to centralize UI checks (`lib/utils/permissions.dart`).
5. Create an audit log collection `audit/{id}` to record privileged changes.

If you want, I can:
- Implement the `users/{uid}.roles` read/write helpers in the codebase.
- Add the Flutter `Permission` helper and update `team_list_page` / `team_tasks_page` to use it.
- Add Cloud Function script to migrate `assignedTeamId` values (needs mapping input).

---

File updated: `permissions model.md` — saved to project root.

Questions before I proceed to implement any code changes (optional):
- Do you want roles to be global-only, team-scoped-only, or both (current doc uses both)?
- Do you prefer role names normalized (e.g., `hr`, `super_admin`) or longer labels?

End of document.
      
