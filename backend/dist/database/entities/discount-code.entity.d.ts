export declare class DiscountCodeEntity {
    id: string;
    name: string;
    code?: string;
    discountPercent: number;
    startAt: Date;
    endAt: Date;
    isActive: boolean;
    createdAt: Date;
}
