import { act, render } from "@testing-library/react-native";
import { Text } from "react-native";
import GoalDetail from "../../../app/goals/[id]";
import GoalHistory from "../../../app/goals/history";
import Goals from "../../../app/goals/index";
import NewGoal from "../../../app/goals/new";
import * as expoRouter from "expo-router";

jest.mock("expo-router", () => {
  const { useEffect } = jest.requireActual("react");
  const state: { focus?: () => void } = {};
  return {
    router: { canGoBack: jest.fn(), back: jest.fn(), replace: jest.fn(), push: jest.fn() },
    useLocalSearchParams: () => ({ id: "goal-1" }),
    useFocusEffect: (callback: () => void) => {
      state.focus = callback;
      useEffect(() => callback(), [callback]);
    },
    __state: state,
  };
});
jest.mock("../NewGoalScreen", () => ({ NewGoalScreen: (props: { onCreated: () => void }) => mockCapture("new", props) }));
jest.mock("../GoalDetailScreen", () => ({ GoalDetailScreen: (props: { onDeleted: () => void }) => mockCapture("detail", props) }));
jest.mock("../GoalsTodayScreen", () => ({ GoalsTodayScreen: (props: { refreshKey?: number }) => mockCapture("today", props) }));
jest.mock("../GoalHistoryScreen", () => ({ GoalHistoryScreen: (props: { refreshKey?: number }) => mockCapture("history", props) }));

const mockProps: Record<string, Record<string, unknown>> = {};
function mockCapture(name: string, props: Record<string, unknown>) {
  mockProps[name] = props;
  return <Text>{name}</Text>;
}


const mockRouter = expoRouter.router as unknown as Record<"canGoBack" | "back" | "replace" | "push", jest.Mock>;
const focusState = (expoRouter as unknown as { __state: { focus?: () => void } }).__state;

beforeEach(() => jest.clearAllMocks());

describe("goal routes", () => {
  it.each([
    ["new", NewGoal, "onCreated"],
    ["detail", GoalDetail, "onDeleted"],
  ])("%s goes back when there is a stack and replaces otherwise", async (name, Route, prop) => {
    await render(<Route />);

    mockRouter.canGoBack.mockReturnValue(true);
    (mockProps[name][prop] as () => void)();
    expect(mockRouter.back).toHaveBeenCalledTimes(1);
    expect(mockRouter.replace).not.toHaveBeenCalled();

    mockRouter.canGoBack.mockReturnValue(false);
    (mockProps[name][prop] as () => void)();
    expect(mockRouter.replace).toHaveBeenCalledWith("/goals");
  });

  it("the history opens the detail of a goal", async () => {
    await render(<GoalHistory />);

    (mockProps.history.onOpen as (id: string) => void)("g-9");

    expect(mockRouter.push).toHaveBeenCalledWith({ pathname: "/goals/[id]", params: { id: "g-9" } });
  });

  it.each([
    ["today", Goals],
    ["history", GoalHistory],
  ])("%s reloads on focus, but not on the first focus", async (name, Route) => {
    await render(<Route />);
    expect(mockProps[name].refreshKey).toBe(0);

    await act(async () => focusState.focus?.());

    expect(mockProps[name].refreshKey).toBe(1);
  });
});
