import 'package:get_it/get_it.dart';
import '../../data/datasources/local/in_memory_database.dart';
import '../../data/datasources/remote/remote_api_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/barber_repository_impl.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/repositories/shop_repository_impl.dart';
import '../../data/repositories/social_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/barber_repository.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/repositories/shop_repository.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../domain/usecases/barber_usecases.dart';
import '../../domain/usecases/booking_usecases.dart';
import '../../domain/usecases/shop_usecases.dart';
import '../../domain/usecases/social_usecases.dart';
import '../../presentation/blocs/auth/auth_cubit.dart';
import '../../presentation/blocs/booking/booking_bloc.dart';
import '../../presentation/blocs/shop_discovery/shop_discovery_cubit.dart';
import '../network/api_client.dart';
import '../network/socket_service.dart';
import '../services/booking_slot_calculator.dart';
import '../services/location_service.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  if (sl.isRegistered<ApiClient>()) return;

  // Core Network & Services
  sl.registerLazySingleton<ApiClient>(() => ApiClient());
  sl.registerLazySingleton<SocketService>(() => SocketService());
  sl.registerLazySingleton<LocationService>(() => const LocationService());
  sl.registerLazySingleton<BookingSlotCalculator>(
    () => const BookingSlotCalculator(),
  );

  // DataSources
  sl.registerLazySingleton<InMemoryDatabase>(() => InMemoryDatabase());
  sl.registerLazySingleton<RemoteApiDataSource>(
    () => RemoteApiDataSource(sl<ApiClient>()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      db: sl<InMemoryDatabase>(),
      remote: sl<RemoteApiDataSource>(),
      socketService: sl<SocketService>(),
    ),
  );
  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(
      db: sl<InMemoryDatabase>(),
      remote: sl<RemoteApiDataSource>(),
      socketService: sl<SocketService>(),
    ),
  );
  sl.registerLazySingleton<BookingRepository>(
    () => BookingRepositoryImpl(
      db: sl<InMemoryDatabase>(),
      remote: sl<RemoteApiDataSource>(),
      calculator: sl<BookingSlotCalculator>(),
    ),
  );
  sl.registerLazySingleton<BarberRepository>(
    () => BarberRepositoryImpl(
      db: sl<InMemoryDatabase>(),
      remote: sl<RemoteApiDataSource>(),
    ),
  );
  sl.registerLazySingleton<SocialRepository>(
    () => SocialRepositoryImpl(
      db: sl<InMemoryDatabase>(),
      remote: sl<RemoteApiDataSource>(),
      socketService: sl<SocketService>(),
    ),
  );

  // UseCases
  sl.registerLazySingleton(() => LoginUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(
    () => RequestRegisterOtpUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton(
    () => VerifyRegisterOtpUseCase(sl<AuthRepository>()),
  );
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => GetNearbyShopsUseCase(sl<ShopRepository>()));
  sl.registerLazySingleton(
    () => GetHighlightedShopsUseCase(sl<ShopRepository>()),
  );
  sl.registerLazySingleton(
    () => GetDaySlotScheduleUseCase(sl<BookingRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateBookingUseCase(sl<BookingRepository>()),
  );
  sl.registerLazySingleton(
    () => CancelBookingUseCase(sl<BookingRepository>()),
  );
  sl.registerLazySingleton(
    () => ConfirmBookingPaidByBarberUseCase(sl<BookingRepository>()),
  );
  sl.registerLazySingleton(
    () => GetBarberIncomeSummaryUseCase(sl<BarberRepository>()),
  );
  sl.registerLazySingleton(() => GetFeedPostsUseCase(sl<SocialRepository>()));
  sl.registerLazySingleton(() => CreatePostUseCase(sl<SocialRepository>()));

  // Presentation BLoCs / Cubits
  sl.registerLazySingleton<AuthCubit>(
    () => AuthCubit(authRepository: sl<AuthRepository>()),
  );
  sl.registerFactory<ShopDiscoveryCubit>(
    () => ShopDiscoveryCubit(
      shopRepository: sl<ShopRepository>(),
      socialRepository: sl<SocialRepository>(),
      locationService: sl<LocationService>(),
    ),
  );
  sl.registerFactory<BookingBloc>(
    () => BookingBloc(
      shopRepository: sl<ShopRepository>(),
      bookingRepository: sl<BookingRepository>(),
      calculator: sl<BookingSlotCalculator>(),
    ),
  );
}
