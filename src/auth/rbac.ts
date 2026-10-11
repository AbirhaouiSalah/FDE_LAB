export type Role = 'recruiter' | 'hm' | 'hrd' | 'dpo' | 'mco';
export type Page =
  | 'overview' | 'pipeline' | 'queue' | 'quality'
  | 'fairness' | 'operations' | 'governance' | 'rubric';

export const RBAC: Record<Role, Page[]> = {
  recruiter: ['overview', 'queue'],
  hm:        ['overview', 'pipeline', 'queue', 'rubric'],
  hrd:       ['overview', 'pipeline', 'queue', 'quality', 'fairness', 'governance', 'rubric'],
  dpo:       ['overview', 'fairness', 'governance', 'rubric'],
  mco:       ['overview', 'pipeline', 'queue', 'quality', 'operations', 'rubric'],
};

export const canAccess = (role: Role, page: Page) => RBAC[role].includes(page);
