import { BookingShift, BookingStatus, PaymentMethod } from './enums';
import { ShopEntity } from './shop.entity';
import { BarberEntity } from './barber.entity';
import { UserEntity } from './user.entity';
export declare class BookingEntity {
    id: string;
    shopId: string;
    shop: ShopEntity;
    barberId: string;
    barber: BarberEntity;
    customerId: string;
    customer: UserEntity;
    bookingDate: string;
    startMinutes: number;
    endMinutes: number;
    shift?: BookingShift | null;
    totalDurationMinutes: number;
    totalPrice: number;
    servicesSnapshot: Array<{
        id: string;
        name: string;
        price: number;
        durationMinutes: number;
    }>;
    paymentMethod: PaymentMethod;
    isPaid: boolean;
    status: BookingStatus;
    completedAt?: Date | null;
    createdAt: Date;
}
