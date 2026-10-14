// src/widgets/AlertPanel/AlertPanel.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { AlertPanel } from "./AlertPanel";

describe("AlertPanel", () => {
  it("affiche le titre et le contenu", () => {
    render(<AlertPanel title="Info"><p>Détail</p></AlertPanel>);
    expect(screen.getByText("Info")).toBeInTheDocument();
    expect(screen.getByText("Détail")).toBeInTheDocument();
  });

  it("utilise role=alert pour critical", () => {
    render(<AlertPanel level="critical" title="Alerte">x</AlertPanel>);
    expect(screen.getByRole("alert")).toBeInTheDocument();
  });

  it("utilise role=status pour info/warning", () => {
    render(<AlertPanel level="warning" title="Attention">x</AlertPanel>);
    expect(screen.getByRole("status")).toBeInTheDocument();
  });

  it("expose le level en data-attr", () => {
    const { container } = render(<AlertPanel level="warning" title="x">y</AlertPanel>);
    expect(container.querySelector("[data-level='warning']")).toBeInTheDocument();
  });
});
