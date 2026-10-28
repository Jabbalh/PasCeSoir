/// Configuration fournie à la compilation : `--dart-define-from-file=env.json`
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

/// Site web : pages de confirmation d'email et de nouveau mot de passe
/// (en attendant les liens profonds Android vers l'application)
const webBaseUrl = String.fromEnvironment('WEB_BASE_URL', defaultValue: 'https://pas-ce-soir.vercel.app');
