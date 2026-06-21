import {
  Injectable,
  NotFoundException,
  ConflictException,
  HttpException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Product } from './entities/product.entity';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { BulkCreateProductsResult } from './dto/bulk-create-products.dto';

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product)
    private productsRepository: Repository<Product>,
  ) {}

  async findAll(tenantId: string): Promise<Product[]> {
    return this.productsRepository.find({
      where: { tenantId, isActive: true },
      order: { createdAt: 'DESC' },
    });
  }

  async findLowStock(tenantId: string): Promise<Product[]> {
    return this.productsRepository
      .createQueryBuilder('product')
      .where('product.tenantId = :tenantId', { tenantId })
      .andWhere('product.stock <= product.minStock')
      .andWhere('product.isActive = true')
      .getMany();
  }

  async findOne(id: string, tenantId: string): Promise<Product> {
    const product = await this.productsRepository.findOne({
      where: { id, tenantId },
    });
    if (!product) {
      throw new NotFoundException(`Product with ID ${id} not found`);
    }
    return product;
  }

  async create(
    createProductDto: CreateProductDto,
    tenantId: string,
  ): Promise<Product> {
    console.log('📦 Backend: Yeni ürün oluşturuluyor:', {
      name: createProductDto.name,
      category: createProductDto.category,
      taxRate: createProductDto.taxRate,
      categoryTaxRateOverride: createProductDto.categoryTaxRateOverride,
      tenantId,
    });

    const product = this.productsRepository.create({
      ...createProductDto,
      tenantId,
    });

    let saved: Product;
    try {
      saved = await this.productsRepository.save(product);
    } catch (error) {
      if (this.isUniqueProductCodeError(error)) {
        const code = (createProductDto?.code || '').trim();
        throw new ConflictException(
          code
            ? `Bu SKU zaten kayıtlı: ${code}. Lütfen farklı bir SKU deneyin.`
            : 'Bu SKU zaten kayıtlı. Lütfen farklı bir SKU deneyin.',
        );
      }
      throw error;
    }

    console.log('✅ Backend: Ürün kaydedildi:', {
      id: saved.id,
      name: saved.name,
      taxRate: saved.taxRate,
      categoryTaxRateOverride: saved.categoryTaxRateOverride,
    });

    return saved;
  }

  async bulkCreate(
    dtos: CreateProductDto[],
    tenantId: string,
  ): Promise<BulkCreateProductsResult> {
    const seenCodes = new Set<string>();
    const seenBarcodes = new Set<string>();

    const results: BulkCreateProductsResult['results'] = [];
    let created = 0;
    let failed = 0;

    for (let index = 0; index < dtos.length; index++) {
      const dto = dtos[index];
      try {
        const code = (dto.code || '').trim();
        if (code) {
          const codeKey = code.toLowerCase();
          if (seenCodes.has(codeKey)) {
            throw new ConflictException(
              `Bu SKU zaten kayıtlı: ${code}. Lütfen farklı bir SKU deneyin.`,
            );
          }
          const existingByCode = await this.productsRepository
            .createQueryBuilder('product')
            .where('product.tenantId = :tenantId', { tenantId })
            .andWhere('LOWER(TRIM(product.code)) = LOWER(TRIM(:code))', {
              code,
            })
            .getOne();
          if (existingByCode) {
            throw new ConflictException(
              `Bu SKU zaten kayıtlı: ${code}. Lütfen farklı bir SKU deneyin.`,
            );
          }
          seenCodes.add(codeKey);
        }

        const barcode = (dto.barcode || '').trim();
        if (barcode) {
          const barcodeKey = barcode.toLowerCase();
          if (seenBarcodes.has(barcodeKey)) {
            throw new ConflictException(
              `Bu barkod zaten kayıtlı: ${barcode}.`,
            );
          }
          const existingByBarcode = await this.productsRepository
            .createQueryBuilder('product')
            .where('product.tenantId = :tenantId', { tenantId })
            .andWhere('LOWER(TRIM(product.barcode)) = LOWER(TRIM(:barcode))', {
              barcode,
            })
            .getOne();
          if (existingByBarcode) {
            throw new ConflictException(
              `Bu barkod zaten kayıtlı: ${barcode}.`,
            );
          }
          seenBarcodes.add(barcodeKey);
        }

        const product = this.productsRepository.create({
          ...dto,
          tenantId,
        });
        const saved = await this.productsRepository.save(product);
        created++;
        results.push({ index, success: true, product: saved });
      } catch (error) {
        failed++;
        const message = this.isUniqueProductCodeError(error)
          ? 'Bu SKU zaten kayıtlı. Lütfen farklı bir SKU deneyin.'
          : this.getErrorMessage(error);
        results.push({ index, success: false, error: message });
      }
    }

    return { created, failed, results };
  }

  async update(
    id: string,
    updateProductDto: UpdateProductDto,
    tenantId: string,
  ): Promise<Product> {
    console.log('✏️ Backend: Ürün güncelleniyor:', {
      id,
      taxRate: updateProductDto.taxRate,
      categoryTaxRateOverride: updateProductDto.categoryTaxRateOverride,
    });

    try {
      await this.productsRepository.update({ id, tenantId }, updateProductDto);
    } catch (error) {
      if (this.isUniqueProductCodeError(error)) {
        const code = (updateProductDto?.code || '').trim();
        throw new ConflictException(
          code
            ? `Bu SKU zaten kayıtlı: ${code}. Lütfen farklı bir SKU deneyin.`
            : 'Bu SKU zaten kayıtlı. Lütfen farklı bir SKU deneyin.',
        );
      }
      throw error;
    }

    const updated = await this.findOne(id, tenantId);

    console.log('✅ Backend: Ürün güncellendi:', {
      id: updated.id,
      name: updated.name,
      taxRate: updated.taxRate,
      categoryTaxRateOverride: updated.categoryTaxRateOverride,
    });

    return updated;
  }

  async remove(id: string, tenantId: string): Promise<void> {
    const product = await this.findOne(id, tenantId);
    await this.productsRepository.remove(product);
  }

  async updateStock(
    id: string,
    quantity: number,
    tenantId: string,
  ): Promise<Product> {
    const product = await this.findOne(id, tenantId);
    product.stock = Number(product.stock) + quantity;
    return this.productsRepository.save(product);
  }

  private getErrorMessage(error: unknown): string {
    if (error instanceof HttpException) {
      const response = error.getResponse();
      if (typeof response === 'string') {
        return response;
      }
      if (typeof response === 'object' && response !== null && 'message' in response) {
        const msg = (response as Record<string, unknown>).message;
        return Array.isArray(msg) ? msg.join(', ') : String(msg);
      }
      return error.message;
    }
    if (error instanceof Error) {
      return error.message;
    }
    return 'Bilinmeyen hata';
  }

  private isUniqueProductCodeError(error: unknown): boolean {
    const { code, message } = this.parseDbError(error);
    if (code === '23505') {
      return true;
    }
    if (!message) {
      return false;
    }
    const normalized = message.toLowerCase();
    return (
      normalized.includes('unique constraint') ||
      normalized.includes('unique constraint failed') ||
      normalized.includes('duplicate key')
    );
  }

  private parseDbError(error: unknown) {
    const result: { code?: string; message?: string } = {};
    if (typeof error === 'object' && error !== null) {
      const record = error as Record<string, unknown>;
      if (typeof record.code === 'string') {
        result.code = record.code;
      } else if (typeof record.code === 'number') {
        result.code = String(record.code);
      }
      if (typeof record.message === 'string') {
        result.message = record.message;
      }
    }
    if (!result.message && error instanceof Error) {
      result.message = error.message;
    }
    return result;
  }
}
