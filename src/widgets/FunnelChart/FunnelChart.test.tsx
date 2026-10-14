// src/widgets/FunnelChart/FunnelChart.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { FunnelChart } from "./FunnelChart";

const stages = [
  { label: "Candidatures", count: 100 },
  { label: "Pré-sélection", count: 60 },
  { label: "Entretien", count: 20 },
];

describe("FunnelChart", () => {
  it("affiche chaque étape", () => {
    render(<FunnelChart label="Entonnoir" stages={stages} />);
    expect(screen.getByText("Candidatures")).toBeInTheDocument();
    expect(screen.getByText("Pré-sélection")).toBeInTheDocument();
    expect(screen.getByText("Entretien")).toBeInTheDocument();
  });

  it("affiche un message vide", () => {
    render(<FunnelChart label="Vide" stages={[]} />);
    expect(screen.getByText("Aucune donnée")).toBeInTheDocument();
  });

  it("calcule les taux par rapport à la 1ère étape", () => {
    render(<FunnelChart label="Entonnoir" stages={stages} />);
    expect(screen.getByText("(60%)")).toBeInTheDocument();
    expect(screen.getByText("(20%)")).toBeInTheDocument();
  });

  it("masque si minSampleSize < k", () => {
    render(<FunnelChart label="Entonnoir" stages={stages} minSampleSize={3} k={5} />);
    expect(screen.queryByText("Candidatures")).not.toBeInTheDocument();
  });
});
