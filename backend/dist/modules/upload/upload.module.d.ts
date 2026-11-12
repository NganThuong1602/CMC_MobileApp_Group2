import { ConfigService } from '@nestjs/config';
export declare class CloudinaryService {
    private readonly config;
    private isConfigured;
    constructor(config: ConfigService);
    uploadBuffer(buffer: Buffer, folder?: string): Promise<string>;
}
export declare class UploadController {
    private readonly cloudinaryService;
    constructor(cloudinaryService: CloudinaryService);
    uploadImages(files: Array<{
        buffer: Buffer;
    }>): Promise<{
        urls: string[];
    }>;
}
export declare class UploadModule {
}
