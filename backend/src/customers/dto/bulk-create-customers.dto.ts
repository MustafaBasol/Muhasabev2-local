import { ArrayMaxSize, ArrayMinSize, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';
import { CreateCustomerDto } from './create-customer.dto';

export class BulkCreateCustomersDto {
  @ApiProperty({ type: [CreateCustomerDto] })
  @ValidateNested({ each: true })
  @Type(() => CreateCustomerDto)
  @ArrayMinSize(1)
  @ArrayMaxSize(2000)
  customers: CreateCustomerDto[];
}

export interface BulkCreateCustomersResultItem {
  index: number;
  success: boolean;
  customer?: unknown;
  error?: string;
}

export interface BulkCreateCustomersResult {
  created: number;
  failed: number;
  results: BulkCreateCustomersResultItem[];
}
