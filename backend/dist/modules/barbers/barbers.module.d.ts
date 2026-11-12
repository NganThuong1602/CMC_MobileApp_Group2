import { Repository } from 'typeorm';
import { BarberEntity, BookingEntity, BookingStatus, NotificationEntity, ShopEntity, UserEntity, UserRole } from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.module';
import { RealtimeGateway } from '../realtime/realtime.module';
export declare class BarbersService {
    private readonly barberRepo;
    private readonly userRepo;
    private readonly shopRepo;
    private readonly bookingRepo;
    private readonly notiRepo;
    private readonly notificationsService;
    private readonly realtimeGateway;
    constructor(barberRepo: Repository<BarberEntity>, userRepo: Repository<UserEntity>, shopRepo: Repository<ShopEntity>, bookingRepo: Repository<BookingEntity>, notiRepo: Repository<NotificationEntity>, notificationsService: NotificationsService, realtimeGateway: RealtimeGateway);
    searchCandidates(query: string): Promise<{
        id: string;
        fullName: string;
        email: string;
        phone: string;
        role: UserRole;
        avatarUrl: string;
    }[]>;
    inviteBarber(managerId: string, emailOrPhone: string, baseSalary?: number): Promise<{
        message: string;
    }>;
    respondInvitation(userId: string, notificationId: string, accept: boolean): Promise<{
        accepted: boolean;
        role?: undefined;
        shopId?: undefined;
    } | {
        accepted: boolean;
        role: UserRole;
        shopId: string;
    }>;
    updateBaseSalary(managerId: string, barberId: string, baseSalary: number): Promise<BarberEntity>;
    removeBarber(managerId: string, barberId: string): Promise<{
        deleted: boolean;
        barberId: string;
    }>;
    getMonthlyHeatmap(userId: string, year: number, month: number): Promise<Record<number, number>>;
    getDayTimeline(userId: string, date: string): Promise<{
        id: string;
        customerName: string;
        customerPhone: string;
        bookingDate: string;
        startMinutes: number;
        endMinutes: number;
        totalPrice: number;
        services: {
            id: string;
            name: string;
            price: number;
            durationMinutes: number;
        }[];
        status: BookingStatus;
        isPaid: boolean;
        paymentMethod: import("../../database/entities").PaymentMethod;
    }[]>;
    getMyIncome(userId: string): Promise<{
        barberId: string;
        shop: ShopEntity;
        isActive: boolean;
        baseSalary: number;
        completedBookingsCount: number;
        completedRevenue: number;
        commissionRate: number;
        commissionAmount: number;
        totalIncome: number;
        expectedPaydayNote: string;
    }>;
}
export declare class BarbersController {
    private readonly service;
    constructor(service: BarbersService);
    searchCandidates(q: string): Promise<{
        id: string;
        fullName: string;
        email: string;
        phone: string;
        role: UserRole;
        avatarUrl: string;
    }[]>;
    invite(user: UserEntity, body: {
        emailOrPhone: string;
        baseSalary?: number;
    }): Promise<{
        message: string;
    }>;
    respondInvite(user: UserEntity, notificationId: string, body: {
        accept: boolean;
    }): Promise<{
        accepted: boolean;
        role?: undefined;
        shopId?: undefined;
    } | {
        accepted: boolean;
        role: UserRole;
        shopId: string;
    }>;
    updateSalary(user: UserEntity, id: string, body: {
        baseSalary: number;
    }): Promise<BarberEntity>;
    removeBarber(user: UserEntity, id: string): Promise<{
        deleted: boolean;
        barberId: string;
    }>;
    getMyProfile(user: UserEntity): Promise<{
        barberId: string;
        shop: ShopEntity;
        isActive: boolean;
        baseSalary: number;
        completedBookingsCount: number;
        completedRevenue: number;
        commissionRate: number;
        commissionAmount: number;
        totalIncome: number;
        expectedPaydayNote: string;
    }>;
    getHeatmap(user: UserEntity, year: string, month: string): Promise<Record<number, number>>;
    getTimeline(user: UserEntity, date: string): Promise<{
        id: string;
        customerName: string;
        customerPhone: string;
        bookingDate: string;
        startMinutes: number;
        endMinutes: number;
        totalPrice: number;
        services: {
            id: string;
            name: string;
            price: number;
            durationMinutes: number;
        }[];
        status: BookingStatus;
        isPaid: boolean;
        paymentMethod: import("../../database/entities").PaymentMethod;
    }[]>;
    getIncome(user: UserEntity): Promise<{
        barberId: string;
        shop: ShopEntity;
        isActive: boolean;
        baseSalary: number;
        completedBookingsCount: number;
        completedRevenue: number;
        commissionRate: number;
        commissionAmount: number;
        totalIncome: number;
        expectedPaydayNote: string;
    }>;
}
export declare class BarbersModule {
}
