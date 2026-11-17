import { newClientRequestId } from "../clientRequestId";

describe("newClientRequestId", () => {
  it("is different each time and fits the 100 characters of the contract", () => {
    const ids = new Set(Array.from({ length: 50 }, () => newClientRequestId()));

    expect(ids.size).toBe(50);
    for (const id of ids) expect(id.length).toBeLessThanOrEqual(100);
  });
});
