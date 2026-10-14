// src/widgets/TimeSeries/TimeSeries.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { TimeSeries } from "./TimeSeries";

const points = [
  { t: "2026-01-01", v: 10 },
  { t: "2026-02-01", v: 20 },
  { t: "2026-03-01", v: 15 },
];

describe("TimeSeries", () => {
  it("affiche un path SVG", () => {
    const { container } = render(<TimeSeries label="Candidats" points={points} />);
    expect(container.querySelector("path")).toBeInTheDocument();
  });

  it("affiche le dernier point", () => {
    render(<TimeSeries label="Candidats" points={points} unit="%" />);
    expect(screen.getByText(/15\.0%/)).toBeInTheDocument();
  });

  it("affiche un path vide si aucun point", () => {
    const { container } = render(<TimeSeries label="Vide" points={[]} />);
    const path = container.querySelector("path");
    expect(path?.getAttribute("d")).toBe("");
  });

  it("masque si minSampleSize < k", () => {
    render(<TimeSeries label="Candidats" points={points} minSampleSize={3} k={5} />);
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
    expect(screen.getByRole("status")).toBeInTheDocument();
  });
});
