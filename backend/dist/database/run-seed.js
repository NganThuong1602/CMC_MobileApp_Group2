"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const core_1 = require("@nestjs/core");
const app_module_1 = require("../app.module");
async function bootstrapSeeder() {
    const appCtx = await core_1.NestFactory.createApplicationContext(app_module_1.AppModule);
    await appCtx.close();
    process.exit(0);
}
bootstrapSeeder().catch((err) => {
    console.error('Seed thất bại:', err);
    process.exit(1);
});
//# sourceMappingURL=run-seed.js.map