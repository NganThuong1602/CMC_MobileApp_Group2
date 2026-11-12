import { Repository } from 'typeorm';
import { BarberEntity, BookingEntity, BookingShift, DiscountCodeEntity, PaymentMethod, ServiceEntity, ShopEntity, UserEntity } from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.module';
export declare class BookingsService {
    private readonly bookingRepo;
    private readonly shopRepo;
    private readonly barberRepo;
    private readonly serviceRepo;
    private readonly discountRepo;
    private readonly notificationsService;
    private static readonly GAP_MINUTES;
    private static readonly MORNING_END;
    private static readonly AFTERNOON_START;
    constructor(bookingRepo: Repository<BookingEntity>, shopRepo: Repository<ShopEntity>, barberRepo: Repository<BarberEntity>, serviceRepo: Repository<ServiceEntity>, discountRepo: Repository<DiscountCodeEntity>, notificationsService: NotificationsService);
    private parseHhMm;
    private formatHhMm;
    private getActiveCooperationDiscount;
    private computeShiftAllocation;
    getAvailableSlots(params: {
        shopId: string;
        barberId: string;
        date: string;
        durationMinutes: number;
    }): Promise<{
        date: string;
        durationMinutes: number;
        gapMinutes: number;
        morningRange: string;
        afternoonRange: string;
        morning: {
            shift: BookingShift;
            label: string;
            shiftRange: string;
            startMinutes: number;
            endMinutes: number;
            assignedRange: string | null;
            bookedCount: number;
            isAvailable: boolean;
            disabledReason: string | null;
        };
        afternoon: {
            shift: BookingShift;
            label: string;
            shiftRange: string;
            startMinutes: number;
            endMinutes: number;
            assignedRange: string | null;
            bookedCount: number;
            isAvailable: boolean;
            disabledReason: string | null;
        };
    }>;
    createBooking(customerId: string, dto: {
        shopId: string;
        barberId: string;
        serviceIds: string[];
        bookingDate: string;
        shift?: BookingShift;
        startMinutes?: number;
        paymentMethod: PaymentMethod;
    }): Promise<BookingEntity>;
    getMyBookings(customerId: string): Promise<BookingEntity[]>;
    cancelBooking(bookingId: string, customerId: string): Promise<BookingEntity>;
    confirmPaidByBarber(bookingId: string, barberUserId: string): Promise<BookingEntity>;
}
export declare class BookingsController {
    private readonly service;
    constructor(service: BookingsService);
    getSlots(shopId: string, barberId: string, date: string, durationMinutes: string): Promise<{
        date: string;
        durationMinutes: number;
        gapMinutes: number;
        morningRange: string;
        afternoonRange: string;
        morning: {
            shift: BookingShift;
            label: string;
            shiftRange: string;
            startMinutes: number;
            endMinutes: number;
            assignedRange: string | null;
            bookedCount: number;
            isAvailable: boolean;
            disabledReason: string | null;
        };
        afternoon: {
            shift: BookingShift;
            label: string;
            shiftRange: string;
            startMinutes: number;
            endMinutes: number;
            assignedRange: string | null;
            bookedCount: number;
            isAvailable: boolean;
            disabledReason: string | null;
        };
    }>;
    create(user: UserEntity, dto: {
        shopId: string;
        barberId: string;
        serviceIds: string[];
        bookingDate: string;
        shift?: BookingShift;
        startMinutes?: number;
        paymentMethod: PaymentMethod;
    }): Promise<BookingEntity>;
    getMine(user: UserEntity): Promise<BookingEntity[]>;
    cancel(id: string, user: UserEntity): Promise<BookingEntity>;
    confirmPaid(id: string, user: UserEntity): Promise<BookingEntity>;
}
export declare class BookingsModule {
}
