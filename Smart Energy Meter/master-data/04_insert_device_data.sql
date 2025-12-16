-- Insert sample device data (matching telemetry simulator - 10 devices, 2 per customer)
INSERT INTO device_master (device_id, customer_id, device_model, firmware_version, installation_date, location, latitude, longitude, device_status, last_maintenance_date, warranty_expiry_date) VALUES
('MTR-10000', 'CUST-8000', 'SmartMeter-Pro-X1', 'v2.4.1', '2023-01-15', 'Building A - Main Floor', 37.7749, -122.4194, 'ACTIVE', '2024-11-01', '2026-01-15'),
('MTR-10001', 'CUST-8000', 'SmartMeter-Pro-X1', 'v2.4.1', '2023-01-20', 'Building B - Basement', 37.7750, -122.4195, 'ACTIVE', '2024-11-05', '2026-01-20'),
('MTR-10002', 'CUST-8001', 'SmartMeter-Plus-S2', 'v2.3.5', '2023-02-10', 'Warehouse Section 1', 30.2672, -97.7431, 'ACTIVE', '2024-10-15', '2026-02-10'),
('MTR-10003', 'CUST-8001', 'SmartMeter-Plus-S2', 'v2.3.5', '2023-02-15', 'Warehouse Section 2', 30.2673, -97.7432, 'ACTIVE', '2024-10-20', '2026-02-15'),
('MTR-10004', 'CUST-8002', 'SmartMeter-Industrial-I5', 'v3.0.2', '2023-03-01', 'Production Line A', 41.8781, -87.6298, 'ACTIVE', '2024-12-01', '2026-03-01'),
('MTR-10005', 'CUST-8002', 'SmartMeter-Industrial-I5', 'v3.0.2', '2023-03-05', 'Production Line B', 41.8782, -87.6299, 'ACTIVE', '2024-12-05', '2026-03-05'),
('MTR-10006', 'CUST-8003', 'SmartMeter-Eco-E3', 'v2.5.0', '2023-04-12', 'Solar Panel Array 1', 45.5152, -122.6784, 'ACTIVE', '2024-09-10', '2026-04-12'),
('MTR-10007', 'CUST-8003', 'SmartMeter-Eco-E3', 'v2.5.0', '2023-04-18', 'Solar Panel Array 2', 45.5153, -122.6785, 'ACTIVE', '2024-09-15', '2026-04-18'),
('MTR-10008', 'CUST-8004', 'SmartMeter-Commercial-C4', 'v2.4.3', '2023-05-01', 'Office Complex - East Wing', 47.6062, -122.3321, 'ACTIVE', '2024-11-20', '2026-05-01'),
('MTR-10009', 'CUST-8004', 'SmartMeter-Commercial-C4', 'v2.4.3', '2023-05-10', 'Office Complex - West Wing', 47.6063, -122.3322, 'ACTIVE', '2024-11-25', '2026-05-10')
ON CONFLICT (device_id) DO NOTHING;
