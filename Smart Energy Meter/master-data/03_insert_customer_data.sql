-- Insert sample customer data (matching telemetry simulator)
INSERT INTO customer_master (customer_id, customer_name, email, phone, address, city, state, postal_code, account_status) VALUES
('CUST-8000', 'Acme Corporation', 'billing@acmecorp.com', '+1-555-0100', '123 Industrial Blvd', 'San Francisco', 'CA', '94102', 'ACTIVE'),
('CUST-8001', 'TechStart Industries', 'accounts@techstart.com', '+1-555-0101', '456 Innovation Drive', 'Austin', 'TX', '78701', 'ACTIVE'),
('CUST-8002', 'Global Manufacturing Ltd', 'finance@globalmanuf.com', '+1-555-0102', '789 Factory Lane', 'Chicago', 'IL', '60601', 'ACTIVE'),
('CUST-8003', 'Green Energy Co', 'info@greenenergy.com', '+1-555-0103', '321 Solar Street', 'Portland', 'OR', '97201', 'ACTIVE'),
('CUST-8004', 'Metro Services Inc', 'admin@metroservices.com', '+1-555-0104', '654 Commerce Way', 'Seattle', 'WA', '98101', 'ACTIVE')
ON CONFLICT (customer_id) DO NOTHING;
