// src/widgets/Heatmap/Heatmap.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { Heatmap } from "./Heatmap";

const rows = ["Nord", "Sud"];
const cols = ["Q1", "Q2"];
const cells = [
  { row: "Nord", col: "Q1", value: 10, sampleSize: 20 },
  { row: "Nord", col: "Q2", value: 20, sampleSize: 20 },
  { row: "Sud",  col: "Q1", value: 15, sampleSize: 2 }, // trop petit
  { row: "Sud",  col: "Q2", value: 25, sampleSize: 20 },
];

describe("Heatmap", () => {
  it("rend une cellule par case", () => {
    const { container } = render(
      <Heatmap label="Heat" rows={rows} cols={cols} cells={cells} k={5} />
    );
    expect(container.querySelectorAll("td")).toHaveLength(4);
  });

  it("masque les cellules sous le seuil k", () => {
    const { container } = render(
      <Heatmap label="Heat" rows={rows} cols={cols} cells={cells} k={5} />
    );
    expect(container.querySelectorAll("[data-masked='true']")).toHaveLength(1);
  });

  it("affiche une note quand des cellules sont masquées", () => {
    render(<Heatmap label="Heat" rows={rows} cols={cols} cells={cells} k={5} />);
    expect(screen.getByText(/masquées/)).toBeInTheDocument();
  });

  it("affiche une cellule vide si absente", () => {
    const partial = [{ row: "Nord", col: "Q1", value: 10, sampleSize: 20 }];
    const { container } = render(
      <Heatmap label="Heat" rows={rows} cols={cols} cells={partial} k={5} />
    );
    expect(container.querySelectorAll("[data-masked='true']").length).toBeGreaterThan(0);
  });
});
