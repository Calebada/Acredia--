import { createFileRoute, Link } from "@tanstack/react-router";
import { Button } from "@/components/ui/button";
import { GraduationCap, Sparkles, ShieldCheck, FileText } from "lucide-react";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "ACREDIA — CIT-U AI Credit Evaluation" },
      { name: "description", content: "AI-assisted transcript analysis and credit evaluation for ETEEAP applicants at Cebu Institute of Technology - University." },
    ],
  }),
  component: Landing,
});

function Landing() {
  return (
    <div className="min-h-screen bg-background">
      <header className="border-b border-border/60 bg-background/80 backdrop-blur">
        <div className="container mx-auto flex h-16 items-center justify-between px-6">
          <div className="flex items-center gap-2">
            <div className="flex h-9 w-9 items-center justify-center rounded-md bg-maroon-gradient">
              <GraduationCap className="h-5 w-5 text-gold" />
            </div>
            <span className="font-display text-xl font-semibold text-primary">ACREDIA</span>
            <span className="ml-2 hidden text-xs uppercase tracking-widest text-muted-foreground sm:inline">CIT-U</span>
          </div>
          <nav className="flex items-center gap-3">
            <Link to="/auth"><Button variant="ghost">Sign in</Button></Link>
            <Link to="/auth"><Button className="bg-primary text-primary-foreground hover:bg-primary-deep">Apply now</Button></Link>
          </nav>
        </div>
      </header>

      <section className="bg-parchment">
        <div className="container mx-auto grid gap-12 px-6 py-24 lg:grid-cols-2 lg:py-32">
          <div className="flex flex-col justify-center">
            <span className="mb-4 inline-flex w-fit items-center gap-2 rounded-full border border-gold/40 bg-gold/10 px-3 py-1 text-xs font-medium uppercase tracking-wider text-primary-deep">
              <Sparkles className="h-3 w-3" /> ETEEAP · AI-assisted
            </span>
            <h1 className="font-display text-5xl font-semibold leading-[1.05] text-primary-deep md:text-6xl">
              Credit your experience. <span className="italic text-primary">Faster.</span>
            </h1>
            <p className="mt-6 max-w-xl text-lg text-muted-foreground">
              ACREDIA reads your transcript, matches your courses against the CIT-U curriculum, and produces a transparent
              evaluation report — usually without waiting for a human evaluator.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link to="/auth"><Button size="lg" className="bg-primary text-primary-foreground hover:bg-primary-deep">Start your application</Button></Link>
              <Link to="/auth"><Button size="lg" variant="outline">Sign in</Button></Link>
            </div>
          </div>
          <div className="grid gap-4">
            {[
              { icon: FileText, title: "Upload your TOR", body: "PDF, JPG, or PNG. Our AI extracts every course, grade, and unit." },
              { icon: Sparkles, title: "AI subject matching", body: "Confidence-scored matches against the CIT-U curriculum, color coded for clarity." },
              { icon: ShieldCheck, title: "Evaluator-verified", body: "Borderline cases are reviewed by faculty. Clear matches auto-finalize." },
            ].map((f) => (
              <div key={f.title} className="rounded-2xl border border-border bg-card p-6 shadow-card">
                <f.icon className="h-6 w-6 text-primary" />
                <h3 className="mt-3 font-display text-xl text-primary-deep">{f.title}</h3>
                <p className="mt-1 text-sm text-muted-foreground">{f.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <footer className="border-t border-border/60 py-8 text-center text-sm text-muted-foreground">
        © {new Date().getFullYear()} Cebu Institute of Technology — University · ACREDIA Prototype
      </footer>
    </div>
  );
}
