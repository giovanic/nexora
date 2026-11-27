import { useFocusEffect } from "expo-router";
import { useCallback, useRef, useState } from "react";

// A number that grows each time the screen regains focus (coming back from another screen), not on the first focus.
// The screen reloads when it changes, so a list never shows what another screen already changed.
export function useRefreshOnFocus(): number {
  const [key, setKey] = useState(0);
  const first = useRef(true);
  useFocusEffect(
    useCallback(() => {
      if (first.current) first.current = false;
      else setKey((value) => value + 1);
    }, []),
  );
  return key;
}
