import { describe, it, expect } from 'vitest';
import { RBAC, canAccess, type Role, type Page } from './rbac';

const ALL_ROLES: Role[] = ['recruiter', 'hm', 'hrd', 'dpo', 'mco'];
const ALL_PAGES: Page[] = [
  'overview', 'pipeline', 'queue', 'quality',
  'fairness', 'operations', 'governance', 'rubric'
];

// Matrice attendue : [role, page] -> boolean
const EXPECTED: Record<Role, Page[]> = {
  recruiter: ['overview', 'queue'],
  hm:        ['overview', 'pipeline', 'queue', 'rubric'],
  hrd:       ['overview', 'pipeline', 'queue', 'quality', 'fairness', 'governance', 'rubric'],
  dpo:       ['overview', 'fairness', 'governance', 'rubric'],
  mco:       ['overview', 'pipeline', 'queue', 'quality', 'operations', 'rubric']
};

describe('RBAC — matrice complète (5 rôles × 8 pages = 40 cas)', () => {
  for (const role of ALL_ROLES) {
    describe(`rôle: ${role}`, () => {
      for (const page of ALL_PAGES) {
        const shouldAccess = EXPECTED[role].includes(page);
        it(`${shouldAccess ? 'CAN' : 'CANNOT'} access ${page}`, () => {
          expect(canAccess(role, page)).toBe(shouldAccess);
        });
      }
    });
  }
});

describe('RBAC — invariants structurels', () => {
  it('chaque rôle a au moins Overview', () => {
    for (const role of ALL_ROLES) {
      expect(canAccess(role, 'overview')).toBe(true);
    }
  });

  it('fairness est restreint à hrd + dpo', () => {
    for (const role of ALL_ROLES) {
      const allowed = ['hrd', 'dpo'].includes(role);
      expect(canAccess(role, 'fairness')).toBe(allowed);
    }
  });

  it('operations est restreint à mco', () => {
    for (const role of ALL_ROLES) {
      expect(canAccess(role, 'operations')).toBe(role === 'mco');
    }
  });

  it("hrd voit toutes les pages sauf operations", () => {
    const hrdPages = [...RBAC.hrd].sort();
    const allExceptOperations = ALL_PAGES.filter(p => p !== "operations").sort();
    expect(hrdPages).toEqual(allExceptOperations);
  });

  it("mco est le seul à voir operations", () => {
    for (const role of ALL_ROLES) {
      expect(canAccess(role, "operations")).toBe(role === "mco");
    }
  });

  it('la matrice RBAC ne contient que des rôles et pages déclarés', () => {
    for (const role of Object.keys(RBAC) as Role[]) {
      expect(ALL_ROLES).toContain(role);
      for (const page of RBAC[role]) {
        expect(ALL_PAGES).toContain(page);
      }
    }
  });
});
