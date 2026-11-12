import { HighlightPlan, ShopPackagePlan, TransactionStatus, TransactionType } from './enums';
export declare class TransactionEntity {
    id: string;
    paymentCode: string;
    transferContent: string;
    userId: string;
    shopId?: string;
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
}
