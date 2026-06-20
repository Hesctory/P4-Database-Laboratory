import * as React from "react";
import { cn } from "@/lib/utils";

export function Alert({
  className,
  variant = "info",
  ...props
}: React.HTMLAttributes<HTMLDivElement> & { variant?: "info" | "error" | "success" }) {
  const styles = {
    info: "border-border bg-muted text-foreground",
    error: "border-destructive/40 bg-destructive/10 text-destructive",
    success: "border-green-600/40 bg-green-600/10 text-green-700",
  };
  return (
    <div
      role="alert"
      className={cn("rounded-md border px-4 py-3 text-sm", styles[variant], className)}
      {...props}
    />
  );
}
