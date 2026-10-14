// src/widgets/Gauge/Gauge.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { Gauge } from "./Gauge";

describe("Gauge", () => {
  it("affiche la valeur formatée", () => {
    render(<Gauge label="Score" value={72.4} />);
    expect(screen.getByText("72%")).toBeInTheDocument();
  });

  it("clampe au-delà de 100", () => {
    render(<Gauge label="Score" value={150} />);
    expect(screen.getByText("100%")).toBeInTheDocument();
  });

  it("clampe en dessous de 0", () => {
    render(<Gauge label="Score" value={-5} />);
    expect(screen.getByText("0%")).toBeInTheDocument();
  });

  it("affiche — si null", () => {
    render(<Gauge label="Score" value={null} />);
    expect(screen.getByText("—")).toBeInTheDocument();
  });

  it("masque si minSampleSize < k", () => {
    render(<Gauge label="Score" value={72} minSampleSize={2} k={5} />);
    expect(screen.queryByRole("img")).not.toBeInTheDocument();
  });
});
