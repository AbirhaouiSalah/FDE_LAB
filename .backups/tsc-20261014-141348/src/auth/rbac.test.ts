import { describe, it, expect } from 'vitest';
import { RBAC, canAccess, type Role } from './rbac';

describe('RBAC matrix', () => {
  it('every role has Overview', () => {
    for (const role of Object.keys(RBAC) as Role[]) {
      expect(canAccess(role, 'overview')).toBe(true);
    }
  });
  it('fairness restricted to hrd + dpo', () => {
    for (const role of Object.keys(RBAC) as Role[]) {
      expect(canAccess(role, 'fairness')).toBe(['hrd','dpo'].includes(role));
    }
  });
});
