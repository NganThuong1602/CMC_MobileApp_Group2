"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var MailerService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.MailerModule = exports.MailerService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const nodemailer = require("nodemailer");
let MailerService = MailerService_1 = class MailerService {
    constructor(config) {
        this.config = config;
        this.logger = new common_1.Logger(MailerService_1.name);
        this.transporter = null;
        const user = this.config.get('SMTP_USER');
        const pass = this.config.get('SMTP_PASS');
        if (user && pass && !user.includes('your_email')) {
            this.transporter = nodemailer.createTransport({
                host: this.config.get('SMTP_HOST', 'smtp.gmail.com'),
                port: Number(this.config.get('SMTP_PORT', '465')),
                secure: this.config.get('SMTP_SECURE', 'true') === 'true',
                auth: { user, pass },
            });
        }
    }
    async sendOtpEmail(toEmail, otpCode, fullName = 'Quý khách') {
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
            this.logger.warn(`[DEV OTP FALLBACK] Chưa cấu hình Gmail App Password. OTP cho ${toEmail}: ${otpCode}`);
            return;
        }
        await this.transporter.sendMail({
            from: this.config.get('SMTP_FROM', '"BarberSmart" <no-reply@barbersmart.vn>'),
            to: toEmail,
            subject: `[BarberSmart] Mã xác thực OTP: ${otpCode}`,
            html,
        });
    }
};
exports.MailerService = MailerService;
exports.MailerService = MailerService = MailerService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], MailerService);
let MailerModule = class MailerModule {
};
exports.MailerModule = MailerModule;
exports.MailerModule = MailerModule = __decorate([
    (0, common_1.Global)(),
    (0, common_1.Module)({
        providers: [MailerService],
        exports: [MailerService],
    })
], MailerModule);
//# sourceMappingURL=mailer.module.js.map