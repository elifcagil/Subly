import Foundation
import Supabase

/// Supabase project coordinates and client construction.
///
/// The anon key is **not a secret** — it is meant to be shipped inside the app.
/// Every table it can reach is protected by row-level security, so a client
/// holding this key can still only touch rows its own `auth.uid()` owns. The
/// `service_role` key bypasses RLS and must never appear in this target.
enum SupabaseConfig {

    static let url = URL(string: "https://jmvvkhyecakzkdzcwybv.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImptdnZraHllY2FremtkemN3eWJ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY4OTY5NjUsImV4cCI6MjEwMjQ3Mjk2NX0.m4N8fEKpQxeX4hyG8I20qoyjCM4LaU0OKNfz4sYCxZU"

    /// Device registration gates the first launch, so a stalled request stalls
    /// the whole app. `URLSession.shared` would wait out its 60s default before
    /// failing — measured, and it leaves the user staring at the registering
    /// screen for a full minute on a network that accepts connections but never
    /// answers (captive portals, dying signal, backend outage).
    ///
    /// Eight seconds is long enough for a slow mobile connection and short
    /// enough that ``OfflineTolerantRegistrationService`` can let the user in
    /// before the wait becomes a wall.
    static func makeClient() -> SupabaseClient {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 15
        // Never queue the request until connectivity returns — fail, let the
        // user through, and retry on the next foreground.
        configuration.waitsForConnectivity = false

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(
                global: SupabaseClientOptions.GlobalOptions(
                    session: URLSession(configuration: configuration)
                )
            )
        )
    }
}
