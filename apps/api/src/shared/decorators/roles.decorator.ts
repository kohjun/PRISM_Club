import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';

/**
 * Gate a route to one of the given roles.
 *
 * Reads `req.user.roles` (populated by `AuthGuard`). Endpoint passes if the
 * intersection is non-empty. Endpoints without `@Roles()` are open to any
 * authenticated user.
 *
 * Used by `RolesGuard` in conjunction with the global `AuthGuard`.
 */
export const Roles = (...roles: string[]): MethodDecorator & ClassDecorator =>
  SetMetadata(ROLES_KEY, roles);
