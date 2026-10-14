// src/widgets/SmallGroupGuard/SmallGroupGuard.test.tsx
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { SmallGroupGuard } from "./SmallGroupGuard";

describe("SmallGroupGuard", () => {
  it("affiche les enfants quand n >= k", () => {
    render(<SmallGroupGuard n={10} k={5}><span>OK</span></SmallGroupGuard>);
    expect(screen.getByText("OK")).toBeInTheDocument();
  });

  it("masque quand n < k", () => {
    render(<SmallGroupGuard n={3} k={5}><span>SECRET</span></SmallGroupGuard>);
    expect(screen.queryByText("SECRET")).not.toBeInTheDocument();
    expect(screen.getByRole("status")).toBeInTheDocument();
  });

  it("masque quand n est null (fail-closed)", () => {
    render(<SmallGroupGuard n={null}><span>SECRET</span></SmallGroupGuard>);
    expect(screen.queryByText("SECRET")).not.toBeInTheDocument();
  });

  it("masque quand n n'est pas un entier", () => {
    render(<SmallGroupGuard n={5.5} k={5}><span>SECRET</span></SmallGroupGuard>);
    expect(screen.queryByText("SECRET")).not.toBeInTheDocument();
  });

  it("utilise k=5 par défaut", () => {
    render(<SmallGroupGuard n={4}><span>SECRET</span></SmallGroupGuard>);
    expect(screen.queryByText("SECRET")).not.toBeInTheDocument();
  });
});
