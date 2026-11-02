import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';

async function bootstrapSeeder() {
  // Khi khởi tạo ApplicationContext, DatabaseSeederService.onModuleInit() sẽ tự động chạy!
  const appCtx = await NestFactory.createApplicationContext(AppModule);
  await appCtx.close();
  process.exit(0);
}

bootstrapSeeder().catch((err) => {
  console.error('Seed thất bại:', err);
  process.exit(1);
});

