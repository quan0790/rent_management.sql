-- ===============================================================
-- Rent / Property Management Database
-- File: rent_management.sql
-- Purpose: CREATE DATABASE + all CREATE TABLE statements + constraints
-- Author: [Your Name]
-- Date: 2025-09-17
-- ===============================================================

/* 1) Create database */
DROP DATABASE IF EXISTS rent_management_db;
CREATE DATABASE rent_management_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE rent_management_db;

-- ========================
-- 2) Tables and schema
-- ========================

-- Roles table (for system users)
CREATE TABLE roles (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE, -- e.g., admin, manager, owner
    description VARCHAR(255)
);

-- System users (admins, property managers)
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    role_id INT NOT NULL,
    username VARCHAR(80) NOT NULL UNIQUE,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL, -- store hashed passwords
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(30),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Properties (a building or complex)
CREATE TABLE properties (
    property_id INT AUTO_INCREMENT PRIMARY KEY,
    owner_user_id INT NULL, -- optional link to users table if owner recorded
    name VARCHAR(150) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_property_name_address UNIQUE (name, address),
    FOREIGN KEY (owner_user_id) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Units within properties (for multi-unit properties)
CREATE TABLE units (
    unit_id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    unit_number VARCHAR(50) NOT NULL, -- e.g., A101, Shop-1
    bedrooms TINYINT UNSIGNED DEFAULT 0,
    floor VARCHAR(50),
    area_sq_m DECIMAL(8,2),
    status ENUM('available','occupied','maintenance','reserved') DEFAULT 'available',
    monthly_rent DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (property_id, unit_number),
    FOREIGN KEY (property_id) REFERENCES properties(property_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Tenants (people renting)
CREATE TABLE tenants (
    tenant_id INT AUTO_INCREMENT PRIMARY KEY,
    national_id VARCHAR(50) UNIQUE, -- optional government ID
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150),
    phone VARCHAR(30),
    emergency_contact_name VARCHAR(150),
    emergency_contact_phone VARCHAR(30),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Leases (associates tenant to a unit, with start/end dates)
CREATE TABLE leases (
    lease_id INT AUTO_INCREMENT PRIMARY KEY,
    unit_id INT NOT NULL,
    tenant_id INT NOT NULL,
    lease_start DATE NOT NULL,
    lease_end DATE, -- NULL for open-ended
    rent_amount DECIMAL(12,2) NOT NULL, -- stored to preserve historic rent even if unit changes price
    security_deposit DECIMAL(12,2) DEFAULT 0,
    billing_cycle ENUM('monthly','quarterly','annually') DEFAULT 'monthly',
    status ENUM('active','terminated','expired','pending') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (unit_id, tenant_id, lease_start), -- prevent duplicate identical leases
    FOREIGN KEY (unit_id) REFERENCES units(unit_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Invoices (generated per billing period)
CREATE TABLE invoices (
    invoice_id INT AUTO_INCREMENT PRIMARY KEY,
    lease_id INT NOT NULL,
    invoice_number VARCHAR(50) NOT NULL UNIQUE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    due_date DATE NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    status ENUM('unpaid','paid','partially_paid','overdue','cancelled') DEFAULT 'unpaid',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lease_id) REFERENCES leases(lease_id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX (lease_id, due_date)
);

-- Payments (can be multiple payments per invoice)
CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(12,2) NOT NULL,
    payment_method ENUM('cash','bank_transfer','mpesa','card','cheque','other') DEFAULT 'mpesa',
    reference VARCHAR(150), -- e.g., transaction id
    received_by_user_id INT,
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (received_by_user_id) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Maintenance requests for units
CREATE TABLE maintenance_requests (
    request_id INT AUTO_INCREMENT PRIMARY KEY,
    unit_id INT NOT NULL,
    tenant_id INT, -- can be reported by tenant or staff
    reported_by VARCHAR(150),
    reported_by_contact VARCHAR(50),
    description TEXT NOT NULL,
    priority ENUM('low','medium','high') DEFAULT 'medium',
    status ENUM('open','in_progress','completed','cancelled') DEFAULT 'open',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    FOREIGN KEY (unit_id) REFERENCES units(unit_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Notifications / Reminders (for rent due, inspection, etc.)
CREATE TABLE reminders (
    reminder_id INT AUTO_INCREMENT PRIMARY KEY,
    lease_id INT NULL,
    tenant_id INT NULL,
    user_id INT NULL, -- staff recipient
    message VARCHAR(500) NOT NULL,
    remind_at DATETIME NOT NULL,
    is_sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (lease_id) REFERENCES leases(lease_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- Audit log (basic actions)
CREATE TABLE audit_logs (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    action VARCHAR(150) NOT NULL,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- ========================
-- 3) Sample data (optional, small seed)
-- ========================

INSERT INTO roles (role_name, description) VALUES
('admin', 'System administrator'),
('manager', 'Property manager'),
('owner', 'Property owner');

-- Example users (password_hash should be a proper hash in real system)
INSERT INTO users (role_id, username, email, password_hash, first_name, last_name, phone)
VALUES
(1, 'admin', 'admin@example.com', 'hashed_pw_here', 'System', 'Admin', '+254700000001'),
(2, 'manager1', 'manager1@example.com', 'hashed_pw_here', 'Mary', 'Manager', '+254700000002');

INSERT INTO properties (owner_user_id, name, address, city, postal_code) VALUES
(2, 'Kilimani Apartments', '12 Kilimani Rd', 'Nairobi', '00100'),
(NULL, 'Riverside Plaza', '34 Riverside Ave', 'Nairobi', '00101');

INSERT INTO units (property_id, unit_number, bedrooms, area_sq_m, monthly_rent) VALUES
(1, 'A101', 2, 72.50, 45000.00),
(1, 'A102', 1, 48.00, 30000.00),
(2, 'Shop-1', 0, 35.00, 25000.00);

INSERT INTO tenants (national_id, first_name, last_name, email, phone) VALUES
('25577273', 'Osukuku', 'James', 'osukuku@example.com', '+254711000111'),
('28484224', 'Maximilla', 'Sikuyu', 'max@example.com', '+254711000222');

INSERT INTO leases (unit_id, tenant_id, lease_start, lease_end, rent_amount, security_deposit, billing_cycle, status) VALUES
(1, 1, '2025-01-01', '2025-12-31', 45000.00, 45000.00, 'monthly', 'active'),
(2, 2, '2025-03-15', NULL, 30000.00, 30000.00, 'monthly', 'active');

-- Example invoice and payment
INSERT INTO invoices (lease_id, invoice_number, period_start, period_end, due_date, amount, status)
VALUES (1, 'INV-2025-0001', '2025-09-01', '2025-09-30', '2025-09-10', 45000.00, 'unpaid');

INSERT INTO payments (invoice_id, payment_date, amount, payment_method, reference, received_by_user_id)
VALUES (1, '2025-09-05 10:15:00', 45000.00, 'mpesa', 'MPESA123456', 2);

-- Update invoice status after payment
UPDATE invoices SET status = 'paid' WHERE invoice_id = 1;

-- ===============================================================
-- End of SQL file
-- ===============================================================
