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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UploadModule = exports.UploadController = exports.CloudinaryService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const platform_express_1 = require("@nestjs/platform-express");
const cloudinary_1 = require("cloudinary");
const auth_guards_1 = require("../../common/auth.guards");
let CloudinaryService = class CloudinaryService {
    constructor(config) {
        this.config = config;
        this.isConfigured = false;
        const cloudName = this.config.get('CLOUDINARY_CLOUD_NAME');
        const apiKey = this.config.get('CLOUDINARY_API_KEY');
        const apiSecret = this.config.get('CLOUDINARY_API_SECRET');
        if (cloudName && apiKey && apiSecret && !cloudName.includes('your_')) {
            cloudinary_1.v2.config({
                cloud_name: cloudName.trim().toLowerCase(),
                api_key: apiKey.trim(),
                api_secret: apiSecret.trim(),
            });
            this.isConfigured = true;
        }
    }
    async uploadBuffer(buffer, folder = 'barbersmart') {
        if (!this.isConfigured) {
            throw new common_1.BadRequestException('Chưa cấu hình CLOUDINARY_CLOUD_NAME / API_KEY / API_SECRET trong .env');
        }
        return new Promise((resolve, reject) => {
            const stream = cloudinary_1.v2.uploader.upload_stream({ folder, resource_type: 'image' }, (error, result) => {
                if (error || !result) {
                    const msg = error?.message || 'Không thể tải ảnh lên Cloudinary';
                    return reject(new common_1.BadRequestException(`Cloudinary từ chối tải ảnh (${msg}). Vui lòng kiểm tra đúng mã Cloud Name trên Cloudinary Dashboard trong file .env.`));
                }
                resolve(result.secure_url);
            });
            stream.end(buffer);
        });
    }
};
exports.CloudinaryService = CloudinaryService;
exports.CloudinaryService = CloudinaryService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], CloudinaryService);
let UploadController = class UploadController {
    constructor(cloudinaryService) {
        this.cloudinaryService = cloudinaryService;
    }
    async uploadImages(files) {
        if (!files || files.length === 0) {
            throw new common_1.BadRequestException('Vui lòng chọn ít nhất 1 file ảnh');
        }
        if (files.length > 5) {
            throw new common_1.BadRequestException('Tối đa chỉ được tải lên 5 ảnh');
        }
        const urls = await Promise.all(files.map((f) => this.cloudinaryService.uploadBuffer(f.buffer)));
        return { urls };
    }
};
exports.UploadController = UploadController;
__decorate([
    (0, common_1.Post)('images'),
    (0, common_1.UseInterceptors)((0, platform_express_1.FilesInterceptor)('files', 5)),
    __param(0, (0, common_1.UploadedFiles)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Array]),
    __metadata("design:returntype", Promise)
], UploadController.prototype, "uploadImages", null);
exports.UploadController = UploadController = __decorate([
    (0, common_1.Controller)('upload'),
    (0, common_1.UseGuards)(auth_guards_1.JwtAuthGuard),
    __metadata("design:paramtypes", [CloudinaryService])
], UploadController);
let UploadModule = class UploadModule {
};
exports.UploadModule = UploadModule;
exports.UploadModule = UploadModule = __decorate([
    (0, common_1.Global)(),
    (0, common_1.Module)({
        controllers: [UploadController],
        providers: [CloudinaryService],
        exports: [CloudinaryService],
    })
], UploadModule);
//# sourceMappingURL=upload.module.js.map