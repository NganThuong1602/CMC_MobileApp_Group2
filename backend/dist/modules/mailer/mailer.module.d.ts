import { ConfigService } from '@nestjs/config';
export declare class MailerService {
    private readonly config;
    private readonly logger;
    private transporter;
    constructor(config: ConfigService);
    sendOtpEmail(toEmail: string, otpCode: string, fullName?: string): Promise<void>;
}
export declare class MailerModule {
}
