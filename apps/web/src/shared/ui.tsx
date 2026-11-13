import { useEffect, useRef, type ReactNode } from "react";

// An error message that takes focus when it appears, so keyboard and screen reader users land on it.
export function ErrorMessage({ children }: { children: ReactNode }) {
  const ref = useRef<HTMLParagraphElement>(null);
  useEffect(() => {
    ref.current?.focus();
  }, []);
  return (
    <p role="alert" tabIndex={-1} ref={ref}>
      {children}
    </p>
  );
}
