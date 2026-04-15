//
//  SupabaseManager.swift
//  Lumoria App
//

import Supabase
import Foundation

// Replace <ANON_KEY> with the public anon key from:
// Supabase Dashboard → Project Settings → API → anon public
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://vhozwnykphqujsiuwesi.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZob3p3bnlrcGhxdWpzaXV3ZXNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNzI0ODAsImV4cCI6MjA5MTY0ODQ4MH0.ip1iNHfXeBUbZePqiKjxZfh-2nxHa_fhXQk4TJzFCkU",
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            emitLocalSessionAsInitialSession: true
        )
    )
)
