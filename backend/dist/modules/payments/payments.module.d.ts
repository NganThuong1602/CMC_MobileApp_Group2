import { OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Repository } from 'typeorm';
import { BookingEntity, HighlightPlan, ServiceEntity, ShopEntity, ShopPackagePlan, TransactionEntity, TransactionStatus, TransactionType, UserEntity } from '../../database/entities';
import { NotificationsService } from '../notifications/notifications.module';
import { RealtimeGateway } from '../realtime/realtime.module';
export declare class PaymentsService implements OnModuleInit {
    private readonly config;
    private readonly txRepo;
    private readonly shopRepo;
    private readonly serviceRepo;
    private readonly userRepo;
    private readonly bookingRepo;
    private readonly realtimeGateway;
    private readonly notificationsService;
    private readonly logger;
    private static readonly SHOP_REG_FEE;
    constructor(config: ConfigService, txRepo: Repository<TransactionEntity>, shopRepo: Repository<ShopEntity>, serviceRepo: Repository<ServiceEntity>, userRepo: Repository<UserEntity>, bookingRepo: Repository<BookingEntity>, realtimeGateway: RealtimeGateway, notificationsService: NotificationsService);
    onModuleInit(): Promise<void>;
    private buildVietQrUrl;
    private randomDigits;
    getRegisterShopCredit(userId: string): Promise<{
        hasCredit: boolean;
        transactionId?: undefined;
        paymentCode?: undefined;
        packagePlan?: undefined;
        amount?: undefined;
        paidAt?: undefined;
        packageMeta?: undefined;
    } | {
        hasCredit: boolean;
        transactionId: string;
        paymentCode: string;
        packagePlan: ShopPackagePlan;
        amount: number;
        paidAt: Date | undefined;
        packageMeta: import("../../database/entities").ShopPackageMeta;
    }>;
    createRegisterShopQr(user: UserEntity, dto: {
        packagePlan?: ShopPackagePlan;
        name?: string;
        address?: string;
        phone?: string;
        openTime?: string;
        closeTime?: string;
        description?: string;
        coverUrl?: string;
        galleryUrls?: string[];
        latitude?: number;
        longitude?: number;
    }): Promise<TransactionEntity>;
    createRenewShopQr(userId: string, plan: ShopPackagePlan): Promise<TransactionEntity>;
    createHighlightQr(userId: string, plan: HighlightPlan): Promise<TransactionEntity>;
    createBookingQr(userId: string, bookingId: string): Promise<TransactionEntity>;
    handleSepayWebhook(authHeader: string | undefined, payload: {
        id?: number | string;
        transferType?: string;
        transferAmount?: number;
        content?: string;
        simulated?: boolean;
    }): Promise<{
        ignored: boolean;
        matched?: undefined;
        reason?: undefined;
        success?: undefined;
        transactionId?: undefined;
    } | {
        matched: boolean;
        ignored?: undefined;
        reason?: undefined;
        success?: undefined;
        transactionId?: undefined;
    } | {
        matched: boolean;
        reason: string;
        ignored?: undefined;
        success?: undefined;
        transactionId?: undefined;
    } | {
        success: boolean;
        transactionId: string;
        paymentCode: string;
        packagePlan: ShopPackagePlan;
        readyForShopForm: boolean;
        id: string;
        transferContent: string;
        userId: string;
        shopId?: string;
        bookingId?: string;
        type: TransactionType;
        highlightPlan?: HighlightPlan;
        amount: number;
        qrImageUrl: string;
        status: TransactionStatus;
        sepayReferenceId?: string;
        metadataJson?: Record<string, any>;
        paidAt?: Date;
        createdAt: Date;
        ignored?: undefined;
        matched?: undefined;
        reason?: undefined;
    } | {
        success: boolean;
        transactionId: string;
        shopId: string;
        referenceId: string;
        id: string;
        paymentCode: string;
        transferContent: string;
        userId: string;
        bookingId?: string;
        type: TransactionType;
        highlightPlan?: HighlightPlan;
        packagePlan?: ShopPackagePlan;
        amount: number;
        qrImageUrl: string;
        status: TransactionStatus;
        sepayReferenceId?: string;
        metadataJson?: Record<string, any>;
        paidAt?: Date;
        createdAt: Date;
        ignored?: undefined;
        matched?: undefined;
        reason?: undefined;
    } | {
        success: boolean;
        transactionId: string;
        shopId: string;
        id: string;
        paymentCode: string;
        transferContent: string;
        userId: string;
        bookingId?: string;
        type: TransactionType;
        highlightPlan?: HighlightPlan;
        packagePlan?: ShopPackagePlan;
        amount: number;
        qrImageUrl: string;
        status: TransactionStatus;
        sepayReferenceId?: string;
        metadataJson?: Record<string, any>;
        paidAt?: Date;
        createdAt: Date;
        ignored?: undefined;
        matched?: undefined;
        reason?: undefined;
    } | {
        success: boolean;
        transactionId: string;
        ignored?: undefined;
        matched?: undefined;
        reason?: undefined;
    }>;
}
export declare class PaymentsController {
    private readonly service;
    constructor(service: PaymentsService);
    getRegisterShopCredit(user: UserEntity): Promise<{
        hasCredit: boolean;
        transactionId?: undefined;
        paymentCode?: undefined;
        packagePlan?: undefined;
        amount?: undefined;
        paidAt?: undefined;
        packageMeta?: undefined;
    } | {
        hasCredit: boolean;
        transactionId: string;
        paymentCode: string;
        packagePlan: ShopPackagePlan;
        amount: number;
        paidAt: Date | undefined;
        packageMeta: import("../../database/entities").ShopPackageMeta;
    }>;
    createRegisterShopQr(user: UserEntity, dto: any): Promise<TransactionEntity>;
    createRenewShopQr(user: UserEntity, body: {
        packagePlan: ShopPackagePlan;
    }): Promise<TransactionEntity>;
    createHighlightQr(user: UserEntity, body: {
        plan: HighlightPlan;
    }): Promise<TransactionEntity>;
    createBookingQr(user: UserEntity, body: {
        bookingId: string;
    }): Promise<TransactionEntity>;
    sepayWebhook(authorization: string | undefined, payload: any): Promise<{
        ignored: boolean;
        matched?: undefined;
        reason?: undefined;
        success?: undefined;
        transactionId?: undefined;
    } | {
        matched: boolean;
        ignored?: undefined;
        reason?: undefined;
        success?: undefined;
        transactionId?: undefined;
    } | {
        matched: boolean;
        reason: string;
        ignored?: undefined;
        success?: undefined;
        transactionId?: undefined;
    } | {
        success: boolean;
        transactionId: string;
        paymentCode: string;
        packagePlan: ShopPackagePlan;
        readyForShopForm: boolean;
        id: string;
        transferContent: string;
        userId: string;
        shopId?: string;
        bookingId?: string;
        type: TransactionType;
        highlightPlan?: HighlightPlan;
        amount: number;
        qrImageUrl: string;
        status: TransactionStatus;
        sepayReferenceId?: string;
        metadataJson?: Record<string, any>;
        paidAt?: Date;
        createdAt: Date;
        ignored?: undefined;
        matched?: undefined;
        reason?: undefined;
    } | {
        success: boolean;
        transactionId: string;
        shopId: string;
        referenceId: string;
        id: string;
        paymentCode: string;
        transferContent: string;
        userId: string;
        bookingId?: string;
        type: TransactionType;
        highlightPlan?: HighlightPlan;
        packagePlan?: ShopPackagePlan;
        amount: number;
        qrImageUrl: string;
        status: TransactionStatus;
        sepayReferenceId?: string;
        metadataJson?: Record<string, any>;
        paidAt?: Date;
        createdAt: Date;
        ignored?: undefined;
        matched?: undefined;
        reason?: undefined;
    } | {
        success: boolean;
        transactionId: string;
        shopId: string;
        id: string;
        paymentCode: string;
        transferContent: string;
        userId: string;
        bookingId?: string;
        type: TransactionType;
        highlightPlan?: HighlightPlan;
        packagePlan?: ShopPackagePlan;
        amount: number;
        qrImageUrl: string;
        status: TransactionStatus;
        sepayReferenceId?: string;
        metadataJson?: Record<string, any>;
        paidAt?: Date;
        createdAt: Date;
        ignored?: undefined;
        matched?: undefined;
        reason?: undefined;
    } | {
        success: boolean;
        transactionId: string;
        ignored?: undefined;
        matched?: undefined;
        reason?: undefined;
    }>;
}
export declare class PaymentsModule {
}
