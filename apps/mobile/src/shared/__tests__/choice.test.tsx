import { render, screen } from "@testing-library/react-native";
import { Choice } from "../ui";

describe("Choice", () => {
  it("does not make a screen reader read the visual marker", async () => {
    await render(<Choice label="Corrida" selected onPress={jest.fn()} />);

    const marker = screen.getByText("[x]");
    expect(marker.props.accessible).toBe(false);
    expect(marker.props.importantForAccessibility).toBe("no");
    expect(screen.getByRole("checkbox", { name: "Corrida" })).toBeChecked();
  });
});
