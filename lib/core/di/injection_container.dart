/// Nơi cấu hình Dependency Injection (Service Locator như GetIt, Riverpod, hoặc Provider).
/// Đăng ký theo thứ tự: Core -> Data Sources -> Repositories -> Use Cases -> Controllers/Blocs.
Future<void> init() async {
  // 1. Core / External (SharedPreferences, Dio/HttpClient, ...)

  // 2. Data Sources (Remote & Local)

  // 3. Repositories (Bind Domain Repository Interface -> Data Repository Implementation)

  // 4. Use Cases (Domain)

  // 5. Blocs / Controllers / Providers (Presentation)
}

