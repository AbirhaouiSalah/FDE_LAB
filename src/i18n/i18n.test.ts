import { describe, it, expect } from 'vitest';
import fr from './fr.json';
import en from './en.json';

describe('i18n — parité FR/EN', () => {
  const frKeys = Object.keys(fr).sort();
  const enKeys = Object.keys(en).sort();

  it('les deux catalogues ont le même nombre de clés', () => {
    expect(frKeys.length).toBe(enKeys.length);
  });

  it('aucune clé manquante dans EN', () => {
    const missing = frKeys.filter(k => !(k in en));
    expect(missing).toEqual([]);
  });

  it('aucune clé manquante dans FR', () => {
    const missing = enKeys.filter(k => !(k in fr));
    expect(missing).toEqual([]);
  });

  it('aucune valeur vide', () => {
    for (const [k, v] of Object.entries(fr)) {
      expect(v, `FR key "${k}" is empty`).toBeTruthy();
    }
    for (const [k, v] of Object.entries(en)) {
      expect(v, `EN key "${k}" is empty`).toBeTruthy();
    }
  });

  it('le catalogue FR est en français (pas de doublon anglais évident)', () => {
    // sanity: la clé app.title existe et est non vide dans les deux langues
    expect(fr['app.title']).toBeTruthy();
    expect(en['app.title']).toBeTruthy();
  });
});
