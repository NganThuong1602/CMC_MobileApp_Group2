import {
  BadRequestException,
  Controller,
  Global,
  Injectable,
  Module,
  Post,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FilesInterceptor } from '@nestjs/platform-express';
import { v2 as cloudinary } from 'cloudinary';
import { JwtAuthGuard } from '../../common/auth.guards';

@Injectable()
export class CloudinaryService {
  private isConfigured = false;

  constructor(private readonly config: ConfigService) {
    const cloudName = this.config.get<string>('CLOUDINARY_CLOUD_NAME');
    const apiKey = this.config.get<string>('CLOUDINARY_API_KEY');
    const apiSecret = this.config.get<string>('CLOUDINARY_API_SECRET');

    if (cloudName && apiKey && apiSecret && !cloudName.includes('your_')) {
      cloudinary.config({
        cloud_name: cloudName.trim().toLowerCase(),
        api_key: apiKey.trim(),
        api_secret: apiSecret.trim(),
      });
      this.isConfigured = true;
    }
  }

  async uploadBuffer(buffer: Buffer, folder = 'barbersmart'): Promise<string> {
    if (!this.isConfigured) {
      throw new BadRequestException(
        'Chưa cấu hình CLOUDINARY_CLOUD_NAME / API_KEY / API_SECRET trong .env',
      );
    }
    return new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { folder, resource_type: 'image' },
        (error, result) => {
          if (error || !result) {
            const msg = error?.message || 'Không thể tải ảnh lên Cloudinary';
            return reject(
              new BadRequestException(
                `Cloudinary từ chối tải ảnh (${msg}). Vui lòng kiểm tra đúng mã Cloud Name trên Cloudinary Dashboard trong file .env.`,
              ),
            );
          }
          resolve(result.secure_url);
        },
      );
      stream.end(buffer);
    });
  }
}

@Controller('upload')
@UseGuards(JwtAuthGuard)
export class UploadController {
  constructor(private readonly cloudinaryService: CloudinaryService) {}

  @Post('images')
  @UseInterceptors(FilesInterceptor('files', 5)) // Giới hạn tối đa 5 ảnh
  async uploadImages(@UploadedFiles() files: Array<{ buffer: Buffer }>) {
    if (!files || files.length === 0) {
      throw new BadRequestException('Vui lòng chọn ít nhất 1 file ảnh');
    }
    if (files.length > 5) {
      throw new BadRequestException('Tối đa chỉ được tải lên 5 ảnh');
    }
    const urls = await Promise.all(
      files.map((f) => this.cloudinaryService.uploadBuffer(f.buffer)),
    );
    return { urls };
  }
}

@Global()
@Module({
  controllers: [UploadController],
  providers: [CloudinaryService],
  exports: [CloudinaryService],
})
export class UploadModule {}

