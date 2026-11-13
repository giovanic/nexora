import { useEffect, useId, useRef, type ReactNode } from "react";

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

// A panel that opens inside a list item. Its heading takes focus when it appears, so a screen
// reader announces it and the keyboard continues from there.
export function Panel({ title, children }: { title: string; children: ReactNode }) {
  const ref = useRef<HTMLHeadingElement>(null);
  const id = useId();
  useEffect(() => {
    ref.current?.focus();
  }, []);
  return (
    <div role="group" aria-labelledby={id}>
      <h3 id={id} tabIndex={-1} ref={ref}>
        {title}
      </h3>
      {children}
    </div>
  );
}
