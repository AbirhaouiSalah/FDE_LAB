// src/widgets/KpiCard/KpiCard.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { KpiCard } from "./KpiCard";

describe("KpiCard", () => {
  it("affiche la valeur formatée", () => {
    render(<KpiCard label="Candidats" value={42.7} />);
    expect(screen.getByText("42.7")).toBeInTheDocument();
  });

  it("affiche — si valeur non finie", () => {
    render(<KpiCard label="Candidats" value={null} />);
    expect(screen.getByText("—")).toBeInTheDocument();
  });

  it("affiche l'unité", () => {
    render(<KpiCard label="Taux" value={12.5} unit="%" />);
    expect(screen.getByText("12.5%")).toBeInTheDocument();
  });

  it("masque la carte si sampleSize < k", () => {
    render(<KpiCard label="Candidats" value={42} sampleSize={3} k={5} />);
    expect(screen.queryByText("42")).not.toBeInTheDocument();
    expect(screen.getByRole("status")).toBeInTheDocument();
  });

  it("affiche la carte si sampleSize >= k", () => {
    render(<KpiCard label="Candidats" value={42} sampleSize={10} k={5} />);
    expect(screen.getByText("42")).toBeInTheDocument();
  });

  it("affiche le delta signé", () => {
    render(<KpiCard label="Candidats" value={42} delta={3.2} trend="up" />);
    expect(screen.getByText("+3.2")).toBeInTheDocument();
  });
});
