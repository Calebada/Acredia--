import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { useAuth } from "@/hooks/use-auth";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { GraduationCap, LogOut, Upload, ClipboardCheck, ShieldCheck } from "lucide-react";

export const Route = createFileRoute("/dashboard")({
  component: Dashboard,
});

function Dashboard() {
  const { user, loading, profile, primaryRole } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!loading && !user) navigate({ to: "/auth" });
  }, [loading, user, navigate]);

  if (loading || !user) return <div className="flex min-h-screen items-center justify-center text-muted-foreground">Loading…</div>;

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b border-border/60 bg-card">
        <div className="container mx-auto flex h-16 items-center justify-between px-6">
          <div className="flex items-center gap-2">
            <div className="flex h-9 w-9 items-center justify-center rounded-md bg-maroon-gradient">
              <GraduationCap className="h-5 w-5 text-gold" />
            </div>
            <span className="font-display text-xl font-semibold text-primary">ACREDIA</span>
          </div>
          <div className="flex items-center gap-4 text-sm">
            <span className="text-muted-foreground">{profile?.full_name ?? user.email}</span>
            <span className="rounded-full bg-gold/20 px-3 py-1 text-xs font-semibold uppercase tracking-wider text-primary-deep">{primaryRole}</span>
            <Button variant="ghost" size="sm" onClick={async () => { await supabase.auth.signOut(); navigate({ to: "/" }); }}>
              <LogOut className="mr-2 h-4 w-4" /> Sign out
            </Button>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-6 py-12">
        <h1 className="font-display text-4xl text-primary-deep">Welcome, {profile?.full_name?.split(" ")[0] ?? "friend"}.</h1>
        <p className="mt-2 text-muted-foreground">Your ACREDIA portal — pick where to go next.</p>

        <div className="mt-10 grid gap-6 md:grid-cols-3">
          <Card className="p-6">
            <Upload className="h-7 w-7 text-primary" />
            <h2 className="mt-3 font-display text-2xl text-primary-deep">Submit a new application</h2>
            <p className="mt-1 text-sm text-muted-foreground">Upload your TOR and let the AI extract & match your subjects.</p>
            <Button className="mt-4 bg-primary text-primary-foreground hover:bg-primary-deep" disabled>Coming next build</Button>
          </Card>

          <Card className="p-6">
            <ClipboardCheck className="h-7 w-7 text-primary" />
            <h2 className="mt-3 font-display text-2xl text-primary-deep">My applications</h2>
            <p className="mt-1 text-sm text-muted-foreground">View your evaluation results, predicted completion, and downloadable reports.</p>
            <Button variant="outline" className="mt-4" disabled>Coming next build</Button>
          </Card>

          {(primaryRole === "evaluator" || primaryRole === "admin") && (
            <Card className="p-6">
              <ShieldCheck className="h-7 w-7 text-primary" />
              <h2 className="mt-3 font-display text-2xl text-primary-deep">Evaluator queue</h2>
              <p className="mt-1 text-sm text-muted-foreground">Review and finalize flagged subject matches.</p>
              <Button variant="outline" className="mt-4" disabled>Coming next build</Button>
            </Card>
          )}
        </div>

        <Card className="mt-10 border-dashed bg-accent/40 p-6">
          <p className="text-sm text-muted-foreground">
            <strong className="text-primary-deep">Foundation ready.</strong> Your database, authentication, role system, design tokens,
            and the seeded BSIT curriculum are live. The next build will wire up TOR upload, OCR + AI subject matching,
            evaluator review, completion forecast, PDF report generation, and the chatbot.
          </p>
        </Card>
      </main>
    </div>
  );
}
