import * as fs from 'fs';
import * as path from 'path';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

function checkDatabaseConfigBeforeBoot(): boolean {
  const envPath = path.resolve(process.cwd(), '.env');
  let dbUrl = process.env.DATABASE_URL ?? '';

  if (!dbUrl && fs.existsSync(envPath)) {
    const raw = fs.readFileSync(envPath, 'utf8');
    const match = raw.match(/^DATABASE_URL=(.*)$/m);
    if (match) dbUrl = match[1].trim();
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

async function bootstrap() {
  if (!checkDatabaseConfigBeforeBoot()) {
    return;
  }

  const app = await NestFactory.create(AppModule);

  app.enableCors({
    origin: '*',
    credentials: true,
  });

  app.setGlobalPrefix('api/v1');

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(
    `🚀 BarberSmart NestJS Backend running on http://localhost:${port}/api/v1`,
  );
}

bootstrap();
