import { ArrayMaxSize, ArrayMinSize, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';
import { CreateProductDto } from './create-product.dto';

export class BulkCreateProductsDto {
  @ApiProperty({ type: [CreateProductDto] })
  @ValidateNested({ each: true })
  @Type(() => CreateProductDto)
  @ArrayMinSize(1)
  @ArrayMaxSize(2000)
  products: CreateProductDto[];
}

export interface BulkCreateProductsResultItem {
  index: number;
  success: boolean;
  product?: unknown;
  error?: string;
}

export interface BulkCreateProductsResult {
  created: number;
  failed: number;
  results: BulkCreateProductsResultItem[];
}
