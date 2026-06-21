import apiClient from './client';

export interface Customer {
  id: string;
  name: string;
  email?: string;
  phone?: string;
  address?: string;
  taxNumber?: string;
  siretNumber?: string;
  company?: string;
  balance: number;
  createdAt: string;
  updatedAt: string;
}

export interface CreateCustomerDto {
  name: string;
  email?: string;
  phone?: string;
  address?: string;
  taxNumber?: string;
  siretNumber?: string;
  company?: string;
}

export interface UpdateCustomerDto {
  name?: string;
  email?: string;
  phone?: string;
  address?: string;
  taxNumber?: string;
  siretNumber?: string;
  company?: string;
}

/**
 * Tüm müşterileri listele (tenant-aware)
 */
export const getCustomers = async (): Promise<Customer[]> => {
  const response = await apiClient.get<Customer[]>('/customers');
  return response.data;
};

/**
 * Tek müşteri getir
 */
export const getCustomer = async (id: string): Promise<Customer> => {
  const response = await apiClient.get<Customer>(`/customers/${id}`);
  return response.data;
};

/**
 * Yeni müşteri oluştur
 */
export const createCustomer = async (data: CreateCustomerDto): Promise<Customer> => {
  const response = await apiClient.post<Customer>('/customers', data);
  return response.data;
};

export interface BulkCreateCustomersResultItem {
  index: number;
  success: boolean;
  customer?: Customer;
  error?: string;
}

export interface BulkCreateCustomersResult {
  created: number;
  failed: number;
  results: BulkCreateCustomersResultItem[];
}

/**
 * Birden fazla müşteriyi tek istekte oluştur (CSV/Excel import için)
 */
export const bulkCreateCustomers = async (
  customers: CreateCustomerDto[]
): Promise<BulkCreateCustomersResult> => {
  const response = await apiClient.post<BulkCreateCustomersResult>('/customers/bulk', {
    customers,
  });
  return response.data;
};

/**
 * Müşteri güncelle
 */
export const updateCustomer = async (
  id: string,
  data: UpdateCustomerDto
): Promise<Customer> => {
  const response = await apiClient.patch<Customer>(`/customers/${id}`, data);
  return response.data;
};

/**
 * Müşteri sil
 */
export const deleteCustomer = async (id: string): Promise<void> => {
  await apiClient.delete(`/customers/${id}`);
};
