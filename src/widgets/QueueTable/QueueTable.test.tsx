// src/widgets/QueueTable/QueueTable.test.tsx
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueueTable } from "./QueueTable";

const rows = [
  { id: "a", label: "Candidat A", status: "En attente", priority: 1, updatedAt: "2026-10-14T10:00:00Z" },
  { id: "b", label: "Candidat B", status: "Relu", priority: 2, updatedAt: "2026-10-13T09:00:00Z" },
];

describe("QueueTable", () => {
  it("affiche une ligne par entrée", () => {
    render(<QueueTable rows={rows} />);
    expect(screen.getAllByRole("row")).toHaveLength(3); // header + 2
  });

  it("affiche un état vide", () => {
    render(<QueueTable rows={[]} emptyMessage="Vide" />);
    expect(screen.getByText("Vide")).toBeInTheDocument();
  });

  it("tronque la date à YYYY-MM-DD", () => {
    render(<QueueTable rows={rows} />);
    expect(screen.getByText("2026-10-14")).toBeInTheDocument();
  });

  it("appelle onSelect au clic", async () => {
    const onSelect = vi.fn();
    render(<QueueTable rows={rows} onSelect={onSelect} />);
    await userEvent.click(screen.getByText("Candidat A"));
    expect(onSelect).toHaveBeenCalledWith("a");
  });
});
