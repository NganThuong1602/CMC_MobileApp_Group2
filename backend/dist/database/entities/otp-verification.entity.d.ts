import { OtpPurpose } from './enums';
export declare class OtpVerificationEntity {
    id: string;
    email: string;
    otpCode: string;
    purpose: OtpPurpose;
    payloadJson?: Record<string, any>;
    expiresAt: Date;
    isUsed: boolean;
    createdAt: Date;
}
