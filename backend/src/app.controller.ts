import { Controller, Get, Res } from '@nestjs/common';
import type { Response } from 'express';
import { join } from 'path';

@Controller()
export class AppController {
  @Get()
  getApp(@Res() res: Response) {
    return res.sendFile(join(process.cwd(), 'public', 'dist', 'index.html'));
  }
}
