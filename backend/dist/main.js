"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const child_process_1 = require("child_process");
const fs = require("fs");
const path = require("path");
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const app_module_1 = require("./app.module");
function checkDatabaseConfigBeforeBoot() {
    const envPath = path.resolve(process.cwd(), '.env');
    let dbUrl = process.env.DATABASE_URL ?? '';
    if (!dbUrl && fs.existsSync(envPath)) {
        const raw = fs.readFileSync(envPath, 'utf8');
        const match = raw.match(/^DATABASE_URL=(.*)$/m);
        if (match)
            dbUrl = match[1].trim();
    }
    if (!dbUrl || dbUrl.includes('[PROJECT-REF]') || dbUrl.includes('[PASSWORD]')) {
        console.log('\n====================================================================');
        console.log('⚠️  CHƯA CẤU HÌNH DATABASE_URL THẬT TRONG FILE backend/.env');
        console.log('--------------------------------------------------------------------');
        console.log('1. Để chạy Backend kết nối PostgreSQL (Supabase):');
        console.log('   Mở file backend/.env và thay dòng DATABASE_URL bằng Connection URI');
        console.log('   của project Supabase (hoặc PostgreSQL local trên máy bạn).');
        console.log('2. MẸO: Bạn VẪN CHẠY ĐƯỢC NGAY ỨNG DỤNG FLUTTER (mobile/) mà không');
        console.log('   cần chờ cấu hình Supabase vì mobile/ đã tích hợp sẵn dữ liệu mẫu!');
        console.log('====================================================================\n');
        return false;
    }
    return true;
}
function freePortIfInUse(port) {
    try {
        if (process.platform === 'win32') {
            const output = (0, child_process_1.execSync)(`netstat -ano | findstr :${port}`, {
                encoding: 'utf8',
                stdio: ['ignore', 'pipe', 'ignore'],
            });
            const pids = new Set();
            for (const line of output.split(/\r?\n/)) {
                if (!line.includes('LISTENING'))
                    continue;
                const parts = line.trim().split(/\s+/);
                const pid = Number(parts[parts.length - 1]);
                if (pid && pid !== process.pid) {
                    pids.add(pid);
                }
            }
            for (const pid of pids) {
                try {
                    (0, child_process_1.execSync)(`taskkill /F /PID ${pid}`, { stdio: 'ignore' });
                }
                catch { }
            }
        }
    }
    catch { }
}
async function listenWithRetry(app, port) {
    try {
        await app.listen(port);
    }
    catch (err) {
        if (err?.code === 'EADDRINUSE') {
            console.warn(`⚠️ Cổng ${port} đang bận bởi tiến trình cũ. Đang tự động giải phóng cổng ${port}...`);
            freePortIfInUse(port);
            await new Promise((r) => setTimeout(r, 800));
            await app.listen(port);
            return;
        }
        throw err;
    }
}
async function bootstrap() {
    if (!checkDatabaseConfigBeforeBoot()) {
        return;
    }
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    app.enableShutdownHooks();
    app.enableCors({
        origin: '*',
        credentials: true,
    });
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        transform: true,
        forbidNonWhitelisted: false,
    }));
    const port = Number(process.env.PORT ?? 3000);
    await listenWithRetry(app, port);
    console.log(`🚀 BarberSmart NestJS Backend running on http://localhost:${port}/api/v1`);
}
bootstrap();
//# sourceMappingURL=main.js.map