import { Global, Injectable, Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailerService {
  private readonly logger = new Logger(MailerService.name);
  private transporter: nodemailer.Transporter | null = null;

  constructor(private readonly config: ConfigService) {
    const user = this.config.get<string>('SMTP_USER');
    const pass = this.config.get<string>('SMTP_PASS');

    if (user && pass && !user.includes('your_email')) {
      this.transporter = nodemailer.createTransport({
        host: this.config.get<string>('SMTP_HOST', 'smtp.gmail.com'),
        port: Number(this.config.get<string>('SMTP_PORT', '465')),
        secure: this.config.get<string>('SMTP_SECURE', 'true') === 'true',
        auth: { user, pass },
      });
    }
  }

  async sendOtpEmail(toEmail: string, otpCode: string, fullName = 'Quý khách'): Promise<void> {
    const html = `
      <div style="font-family: Inter, Arial, sans-serif; max-width: 480px; margin: 0 auto; border: 1px solid #E5E7EB; border-radius: 16px; padding: 24px;">
        <h2 style="color: #00A859; margin-top: 0;">BARBERSMART</h2>
        <p style="color: #333333;">Xin chào <b>${fullName}</b>,</p>
        <p style="color: #555555;">Mã xác thực OTP 6 chữ số của bạn là:</p>
        <div style="background: #E8F8F0; color: #00A859; font-size: 28px; font-weight: bold; letter-spacing: 6px; text-align: center; padding: 16px; border-radius: 12px; margin: 16px 0;">
          ${otpCode}
        </div>
        <p style="color: #888888; font-size: 13px;">Mã có hiệu lực trong vòng 5 phút. Tuyệt đối không chia sẻ mã này cho người khác.</p>
      </div>
    `;

    if (!this.transporter) {
      this.logger.warn(
        `[DEV OTP FALLBACK] Chưa cấu hình Gmail App Password. OTP cho ${toEmail}: ${otpCode}`,
      );
      return;
    }

    await this.transporter.sendMail({
      from: this.config.get<string>('SMTP_FROM', '"BarberSmart" <no-reply@barbersmart.vn>'),
      to: toEmail,
      subject: `[BarberSmart] Mã xác thực OTP: ${otpCode}`,
      html,
    });
  }
}

@Global()
@Module({
  providers: [MailerService],
  exports: [MailerService],
})
export class MailerModule {}

