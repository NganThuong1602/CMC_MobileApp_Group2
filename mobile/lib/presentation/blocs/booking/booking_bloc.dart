import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/services/booking_slot_calculator.dart';
import '../../../domain/entities/barber_entity.dart';
import '../../../domain/entities/service_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../../domain/entities/time_slot_entity.dart';
import '../../../domain/repositories/booking_repository.dart';
import '../../../domain/repositories/shop_repository.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

class BookingInitialized extends BookingEvent {
  final String shopId;
  final String? preselectedBarberId;
  final String? currentUserId;

  const BookingInitialized({
    required this.shopId,
    this.preselectedBarberId,
    this.currentUserId,
  });

  @override
  List<Object?> get props => [shopId, preselectedBarberId, currentUserId];
}

class BookingBarberSelected extends BookingEvent {
  final BarberEntity barber;
  const BookingBarberSelected(this.barber);

  @override
  List<Object?> get props => [barber];
}

class BookingServiceToggled extends BookingEvent {
  final ServiceEntity service;
  const BookingServiceToggled(this.service);

  @override
  List<Object?> get props => [service];
}

class BookingDateChanged extends BookingEvent {
  final DateTime date;
  const BookingDateChanged(this.date);

  @override
  List<Object?> get props => [date];
}

class BookingSlotSelected extends BookingEvent {
  final TimeSlotEntity slot;
  const BookingSlotSelected(this.slot);

  @override
  List<Object?> get props => [slot];
}

class BookingPaymentMethodChanged extends BookingEvent {
  final PaymentMethod method;
  const BookingPaymentMethodChanged(this.method);

  @override
  List<Object?> get props => [method];
}

class BookingSubmitted extends BookingEvent {
  final String customerId;
  const BookingSubmitted(this.customerId);

  @override
  List<Object?> get props => [customerId];
}

class BookingState extends Equatable {
  final ShopEntity? shop;
  final List<BarberEntity> barbers;
  final List<ServiceEntity> services;
  final BarberEntity? selectedBarber;
  final List<ServiceEntity> selectedServices;
  final int totalPrice;
  final int totalDurationMinutes;
  final DateTime selectedDate;
  final DaySlotSchedule? daySchedule;
  final TimeSlotEntity? selectedSlot;
  final PaymentMethod paymentMethod;
  final bool isLoading;
  final String? errorMessage;
  final CreatedBookingBundle? createdBundle;
  final String? currentUserId;

  const BookingState({
    this.shop,
    this.barbers = const [],
    this.services = const [],
    this.selectedBarber,
    this.selectedServices = const [],
    this.totalPrice = 0,
    this.totalDurationMinutes = 0,
    required this.selectedDate,
    this.daySchedule,
    this.selectedSlot,
    this.paymentMethod = PaymentMethod.atShop,
    this.isLoading = false,
    this.errorMessage,
    this.createdBundle,
    this.currentUserId,
  });

  factory BookingState.initial() {
    final now = DateTime.now();
    return BookingState(
      selectedDate: DateTime(now.year, now.month, now.day),
    );
  }

  BookingState copyWith({
    ShopEntity? shop,
    List<BarberEntity>? barbers,
    List<ServiceEntity>? services,
    BarberEntity? selectedBarber,
    List<ServiceEntity>? selectedServices,
    int? totalPrice,
    int? totalDurationMinutes,
    DateTime? selectedDate,
    DaySlotSchedule? daySchedule,
    TimeSlotEntity? selectedSlot,
    bool clearSelectedSlot = false,
    PaymentMethod? paymentMethod,
    bool? isLoading,
    String? errorMessage,
    CreatedBookingBundle? createdBundle,
    String? currentUserId,
  }) {
    return BookingState(
      shop: shop ?? this.shop,
      barbers: barbers ?? this.barbers,
      services: services ?? this.services,
      selectedBarber: selectedBarber ?? this.selectedBarber,
      selectedServices: selectedServices ?? this.selectedServices,
      totalPrice: totalPrice ?? this.totalPrice,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      selectedDate: selectedDate ?? this.selectedDate,
      daySchedule: daySchedule ?? this.daySchedule,
      selectedSlot:
          clearSelectedSlot ? null : (selectedSlot ?? this.selectedSlot),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      createdBundle: createdBundle ?? this.createdBundle,
      currentUserId: currentUserId ?? this.currentUserId,
    );
  }

  @override
  List<Object?> get props => [
        shop,
        barbers,
        services,
        selectedBarber,
        selectedServices,
        totalPrice,
        totalDurationMinutes,
        selectedDate,
        daySchedule,
        selectedSlot,
        paymentMethod,
        isLoading,
        errorMessage,
        createdBundle,
      ];
}

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final ShopRepository shopRepository;
  final BookingRepository bookingRepository;
  final BookingSlotCalculator calculator;

  BookingBloc({
    required this.shopRepository,
    required this.bookingRepository,
    required this.calculator,
  }) : super(BookingState.initial()) {
    on<BookingInitialized>(_onInitialized);
    on<BookingBarberSelected>(_onBarberSelected);
    on<BookingServiceToggled>(_onServiceToggled);
    on<BookingDateChanged>(_onDateChanged);
    on<BookingSlotSelected>(_onSlotSelected);
    on<BookingPaymentMethodChanged>(_onPaymentMethodChanged);
    on<BookingSubmitted>(_onSubmitted);
  }

  Future<void> _onInitialized(
    BookingInitialized event,
    Emitter<BookingState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, currentUserId: event.currentUserId));
    final shopRes = await shopRepository.getShopById(event.shopId);
    final barbersRes = await shopRepository.getShopBarbers(event.shopId);
    final servicesRes = await shopRepository.getShopServices(event.shopId);

    if (shopRes.isFailure) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: shopRes.failure!.message,
        ),
      );
      return;
    }

    final barbers = barbersRes.data ?? [];
    final services = servicesRes.data ?? [];
    BarberEntity? initialBarber = barbers.isNotEmpty ? barbers.first : null;
    if (event.preselectedBarberId != null) {
      final matched =
          barbers.where((b) => b.id == event.preselectedBarberId).toList();
      if (matched.isNotEmpty) initialBarber = matched.first;
    }

    final initialServices = services.isNotEmpty ? [services.first] : <ServiceEntity>[];
    final summary = calculator.calculateServicesSummary(initialServices);

    DaySlotSchedule? schedule;
    if (initialBarber != null) {
      final schedRes = await bookingRepository.getDaySlotSchedule(
        shopId: event.shopId,
        barberId: initialBarber.id,
        date: state.selectedDate,
        totalDurationMinutes: summary.totalDurationMinutes,
        currentUserId: event.currentUserId,
      );
      schedule = schedRes.data;
    }

    emit(
      state.copyWith(
        shop: shopRes.data,
        barbers: barbers,
        services: services,
        selectedBarber: initialBarber,
        selectedServices: initialServices,
        totalPrice: summary.totalPrice,
        totalDurationMinutes: summary.totalDurationMinutes,
        daySchedule: schedule,
        clearSelectedSlot: true,
        isLoading: false,
      ),
    );
  }

  Future<void> _refreshSchedule(Emitter<BookingState> emit) async {
    if (state.shop == null || state.selectedBarber == null) return;
    final res = await bookingRepository.getDaySlotSchedule(
      shopId: state.shop!.id,
      barberId: state.selectedBarber!.id,
      date: state.selectedDate,
      totalDurationMinutes: state.totalDurationMinutes,
      currentUserId: state.currentUserId,
    );
    if (res.isSuccess) {
      emit(
        state.copyWith(
          daySchedule: res.data,
          clearSelectedSlot: true,
        ),
      );
    }
  }

  Future<void> _onBarberSelected(
    BookingBarberSelected event,
    Emitter<BookingState> emit,
  ) async {
    emit(state.copyWith(selectedBarber: event.barber, clearSelectedSlot: true));
    await _refreshSchedule(emit);
  }

  Future<void> _onServiceToggled(
    BookingServiceToggled event,
    Emitter<BookingState> emit,
  ) async {
    final current = List<ServiceEntity>.from(state.selectedServices);
    final exists = current.any((s) => s.id == event.service.id);
    if (exists) {
      current.removeWhere((s) => s.id == event.service.id);
    } else {
      current.add(event.service);
    }
    final summary = calculator.calculateServicesSummary(current);
    emit(
      state.copyWith(
        selectedServices: current,
        totalPrice: summary.totalPrice,
        totalDurationMinutes: summary.totalDurationMinutes,
        clearSelectedSlot: true,
      ),
    );
    await _refreshSchedule(emit);
  }

  Future<void> _onDateChanged(
    BookingDateChanged event,
    Emitter<BookingState> emit,
  ) async {
    emit(state.copyWith(selectedDate: event.date, clearSelectedSlot: true));
    await _refreshSchedule(emit);
  }

  void _onSlotSelected(
    BookingSlotSelected event,
    Emitter<BookingState> emit,
  ) {
    if (!event.slot.isSelectable) return;
    emit(state.copyWith(selectedSlot: event.slot));
  }

  void _onPaymentMethodChanged(
    BookingPaymentMethodChanged event,
    Emitter<BookingState> emit,
  ) {
    emit(state.copyWith(paymentMethod: event.method));
  }

  Future<void> _onSubmitted(
    BookingSubmitted event,
    Emitter<BookingState> emit,
  ) async {
    if (state.shop == null ||
        state.selectedBarber == null ||
        state.selectedServices.isEmpty ||
        state.selectedSlot == null) {
      emit(
        state.copyWith(
          errorMessage:
              'Vui lòng chọn đầy đủ Barber, Dịch vụ và Khung giờ còn trống!',
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true));
    final res = await bookingRepository.createBooking(
      shopId: state.shop!.id,
      barberId: state.selectedBarber!.id,
      customerId: event.customerId,
      serviceIds: state.selectedServices.map((s) => s.id).toList(),
      date: state.selectedDate,
      startMinutes: state.selectedSlot!.startMinutes,
      paymentMethod: state.paymentMethod,
    );

    res.fold(
      onFailure: (f) => emit(
        state.copyWith(isLoading: false, errorMessage: f.message),
      ),
      onSuccess: (bundle) => emit(
        state.copyWith(
          isLoading: false,
          createdBundle: bundle,
        ),
      ),
    );
  }
}

