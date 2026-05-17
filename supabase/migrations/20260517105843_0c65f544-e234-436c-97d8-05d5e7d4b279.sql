
-- ============= ENUMS =============
CREATE TYPE public.app_role AS ENUM ('applicant', 'evaluator', 'admin');
CREATE TYPE public.app_status AS ENUM ('draft','submitted','ocr_processing','ocr_failed','matching','pending_review','auto_finalized','finalized');
CREATE TYPE public.match_status AS ENUM ('auto_credited','tentative','rejected','evaluator_approved','evaluator_overridden','evaluator_added');

-- ============= PROFILES =============
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- ============= USER ROLES =============
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role app_role NOT NULL,
  UNIQUE (user_id, role)
);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

-- Profile auto-create on signup + default applicant role
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email), NEW.email);
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'applicant');
  RETURN NEW;
END; $$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============= PROGRAMS / CURRICULUM =============
CREATE TABLE public.programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  total_units INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.curriculum_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id UUID NOT NULL REFERENCES public.programs(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  units INT NOT NULL DEFAULT 3,
  year_level INT NOT NULL DEFAULT 1,
  semester INT NOT NULL DEFAULT 1,
  prereqs TEXT[] NOT NULL DEFAULT '{}'
);
ALTER TABLE public.curriculum_subjects ENABLE ROW LEVEL SECURITY;

-- ============= APPLICATIONS =============
CREATE TABLE public.applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  applicant_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  program_id UUID NOT NULL REFERENCES public.programs(id),
  full_name TEXT NOT NULL,
  prior_school TEXT,
  prior_program TEXT,
  years_experience INT DEFAULT 0,
  status app_status NOT NULL DEFAULT 'draft',
  evaluator_id UUID REFERENCES auth.users(id),
  evaluator_remarks TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  finalized_at TIMESTAMPTZ
);
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;

-- ============= TOR DOCUMENT =============
CREATE TABLE public.tor_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  file_path TEXT NOT NULL,
  ocr_status TEXT NOT NULL DEFAULT 'pending',
  ocr_raw TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.tor_documents ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.tor_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  code TEXT,
  title TEXT,
  grade TEXT,
  units NUMERIC,
  raw_text TEXT
);
ALTER TABLE public.tor_subjects ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.subject_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  tor_subject_id UUID REFERENCES public.tor_subjects(id) ON DELETE CASCADE,
  curriculum_subject_id UUID REFERENCES public.curriculum_subjects(id),
  confidence NUMERIC NOT NULL DEFAULT 0,
  status match_status NOT NULL,
  reason TEXT,
  evaluator_note TEXT,
  flagged_by_applicant BOOLEAN NOT NULL DEFAULT FALSE,
  applicant_flag_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.subject_matches ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.predictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL UNIQUE REFERENCES public.applications(id) ON DELETE CASCADE,
  semesters_min INT NOT NULL,
  semesters_max INT NOT NULL,
  plan JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.predictions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  file_path TEXT,
  payload JSONB NOT NULL,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.chat_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_key TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- ============= RLS POLICIES =============
-- profiles
CREATE POLICY "users view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "users update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "admins view all profiles" ON public.profiles FOR SELECT USING (public.has_role(auth.uid(),'admin') OR public.has_role(auth.uid(),'evaluator'));

-- user_roles (read own; admin can read all)
CREATE POLICY "users view own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "admins view all roles" ON public.user_roles FOR SELECT USING (public.has_role(auth.uid(),'admin'));
CREATE POLICY "admins insert roles" ON public.user_roles FOR INSERT WITH CHECK (public.has_role(auth.uid(),'admin'));
CREATE POLICY "admins delete roles" ON public.user_roles FOR DELETE USING (public.has_role(auth.uid(),'admin'));

-- programs & curriculum: readable by all authenticated
CREATE POLICY "auth read programs" ON public.programs FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage programs" ON public.programs FOR ALL USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));
CREATE POLICY "auth read curriculum" ON public.curriculum_subjects FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage curriculum" ON public.curriculum_subjects FOR ALL USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

-- applications
CREATE POLICY "applicants view own apps" ON public.applications FOR SELECT USING (auth.uid() = applicant_id);
CREATE POLICY "staff view all apps" ON public.applications FOR SELECT USING (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));
CREATE POLICY "applicants insert own apps" ON public.applications FOR INSERT WITH CHECK (auth.uid() = applicant_id);
CREATE POLICY "applicants update own draft apps" ON public.applications FOR UPDATE USING (auth.uid() = applicant_id);
CREATE POLICY "staff update apps" ON public.applications FOR UPDATE USING (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));

-- helper: app owner check
CREATE OR REPLACE FUNCTION public.owns_application(_app_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS(SELECT 1 FROM public.applications WHERE id = _app_id AND applicant_id = auth.uid())
$$;

-- tor_documents
CREATE POLICY "owners view tor docs" ON public.tor_documents FOR SELECT USING (public.owns_application(application_id) OR public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));
CREATE POLICY "owners insert tor docs" ON public.tor_documents FOR INSERT WITH CHECK (public.owns_application(application_id));
CREATE POLICY "staff update tor docs" ON public.tor_documents FOR UPDATE USING (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));

-- tor_subjects
CREATE POLICY "owners view tor subj" ON public.tor_subjects FOR SELECT USING (public.owns_application(application_id) OR public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));
CREATE POLICY "staff manage tor subj" ON public.tor_subjects FOR ALL USING (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));

-- subject_matches
CREATE POLICY "owners view matches" ON public.subject_matches FOR SELECT USING (public.owns_application(application_id) OR public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));
CREATE POLICY "owners flag matches" ON public.subject_matches FOR UPDATE USING (public.owns_application(application_id));
CREATE POLICY "staff manage matches" ON public.subject_matches FOR ALL USING (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));

-- predictions
CREATE POLICY "owners view predictions" ON public.predictions FOR SELECT USING (public.owns_application(application_id) OR public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));
CREATE POLICY "staff manage predictions" ON public.predictions FOR ALL USING (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));

-- reports
CREATE POLICY "owners view reports" ON public.reports FOR SELECT USING (public.owns_application(application_id) OR public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));
CREATE POLICY "staff manage reports" ON public.reports FOR ALL USING (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin'));

-- chat
CREATE POLICY "users view own conversations" ON public.chat_conversations FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);
CREATE POLICY "users insert conversations" ON public.chat_conversations FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);
CREATE POLICY "users view own messages" ON public.chat_messages FOR SELECT USING (EXISTS(SELECT 1 FROM public.chat_conversations c WHERE c.id = conversation_id AND (c.user_id = auth.uid() OR c.user_id IS NULL)));
CREATE POLICY "users insert messages" ON public.chat_messages FOR INSERT WITH CHECK (EXISTS(SELECT 1 FROM public.chat_conversations c WHERE c.id = conversation_id AND (c.user_id = auth.uid() OR c.user_id IS NULL)));

-- ============= STORAGE BUCKETS =============
INSERT INTO storage.buckets (id, name, public) VALUES ('tor-documents','tor-documents', false);
INSERT INTO storage.buckets (id, name, public) VALUES ('reports','reports', false);

CREATE POLICY "owners upload tor files" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='tor-documents' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "owners read tor files" ON storage.objects FOR SELECT TO authenticated USING (bucket_id='tor-documents' AND ((storage.foldername(name))[1] = auth.uid()::text OR public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin')));
CREATE POLICY "staff read reports" ON storage.objects FOR SELECT TO authenticated USING (bucket_id='reports' AND (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin') OR (storage.foldername(name))[1] = auth.uid()::text));
CREATE POLICY "staff write reports" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id='reports' AND (public.has_role(auth.uid(),'evaluator') OR public.has_role(auth.uid(),'admin')));
