-- SMART PARKING DBMS — FINAL SUBMISSION
-- MySQL / MariaDB
-- Run this file from top to bottom.

DROP DATABASE IF EXISTS smart_parking;
CREATE DATABASE smart_parking;
USE smart_parking;

CREATE TABLE ParkingLot (
    lot_id INT AUTO_INCREMENT PRIMARY KEY,
    lot_name VARCHAR(100) NOT NULL,
    location VARCHAR(150) NOT NULL,
    total_slots INT NOT NULL CHECK (total_slots > 0)
);

CREATE TABLE ParkingSlot (
    slot_id INT AUTO_INCREMENT PRIMARY KEY,
    lot_id INT NOT NULL,
    slot_number VARCHAR(10) NOT NULL,
    slot_type ENUM('CAR','BIKE','HANDICAP','EV') NOT NULL DEFAULT 'CAR',
    status ENUM('FREE','OCCUPIED','MAINTENANCE') NOT NULL DEFAULT 'FREE',
    FOREIGN KEY (lot_id) REFERENCES ParkingLot(lot_id) ON DELETE CASCADE,
    UNIQUE KEY uq_lot_slot (lot_id, slot_number)
);

CREATE TABLE Vehicle (
    vehicle_id INT AUTO_INCREMENT PRIMARY KEY,
    plate_number VARCHAR(20) NOT NULL UNIQUE,
    vehicle_type ENUM('CAR','BIKE','HANDICAP','EV') NOT NULL,
    owner_name VARCHAR(100),
    phone VARCHAR(15)
);

CREATE TABLE RateCard (
    rate_id INT AUTO_INCREMENT PRIMARY KEY,
    lot_id INT NOT NULL,
    vehicle_type ENUM('CAR','BIKE','HANDICAP','EV') NOT NULL,
    rate_per_hour DECIMAL(6,2) NOT NULL,
    grace_minutes INT NOT NULL DEFAULT 10,
    FOREIGN KEY (lot_id) REFERENCES ParkingLot(lot_id),
    UNIQUE KEY uq_lot_vtype (lot_id, vehicle_type)
);

CREATE TABLE ParkingSession (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    vehicle_id INT NOT NULL,
    slot_id INT NOT NULL,
    entry_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    exit_time DATETIME NULL,
    status ENUM('ACTIVE','COMPLETED') NOT NULL DEFAULT 'ACTIVE',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vehicle_id) REFERENCES Vehicle(vehicle_id),
    FOREIGN KEY (slot_id) REFERENCES ParkingSlot(slot_id)
);

CREATE TABLE Payment (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NOT NULL UNIQUE,
    duration_mins INT NOT NULL,
    amount DECIMAL(8,2) NOT NULL,
    payment_mode ENUM('CASH','CARD','UPI','WALLET') NOT NULL DEFAULT 'CASH',
    payment_status ENUM('PENDING','PAID','FAILED','REFUNDED') NOT NULL DEFAULT 'PAID',
    staff_id INT NULL,
    payment_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES ParkingSession(session_id)
);

CREATE TABLE Staff (
    staff_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    role ENUM('ATTENDANT','SUPERVISOR','ADMIN') NOT NULL DEFAULT 'ATTENDANT',
    lot_id INT NOT NULL,
    FOREIGN KEY (lot_id) REFERENCES ParkingLot(lot_id)
);

ALTER TABLE Payment
    ADD CONSTRAINT fk_payment_staff FOREIGN KEY (staff_id) REFERENCES Staff(staff_id);

CREATE INDEX idx_slot_lot_status ON ParkingSlot(lot_id, status, slot_type);
CREATE INDEX idx_session_status ON ParkingSession(status);
CREATE INDEX idx_vehicle_plate ON Vehicle(plate_number);

DELIMITER $$

CREATE TRIGGER trg_session_start
AFTER INSERT ON ParkingSession
FOR EACH ROW
BEGIN
    UPDATE ParkingSlot SET status = 'OCCUPIED' WHERE slot_id = NEW.slot_id;
END$$

CREATE TRIGGER trg_session_end
AFTER UPDATE ON ParkingSession
FOR EACH ROW
BEGIN
    IF NEW.status = 'COMPLETED' AND OLD.status = 'ACTIVE' THEN
        UPDATE ParkingSlot SET status = 'FREE' WHERE slot_id = NEW.slot_id;
    END IF;
END$$

CREATE PROCEDURE sp_allocate_slot (
    IN p_plate VARCHAR(20),
    IN p_vtype VARCHAR(10),
    IN p_lot_id INT,
    IN p_owner VARCHAR(100),
    IN p_phone VARCHAR(15),
    OUT p_slot_no VARCHAR(10),
    OUT p_session_id INT
)
BEGIN
    DECLARE v_vehicle_id INT;
    DECLARE v_slot_id INT;

    SELECT vehicle_id INTO v_vehicle_id
    FROM Vehicle WHERE plate_number = p_plate LIMIT 1;

    IF v_vehicle_id IS NULL THEN
        INSERT INTO Vehicle (plate_number, vehicle_type, owner_name, phone)
        VALUES (p_plate, p_vtype, p_owner, p_phone);
        SET v_vehicle_id = LAST_INSERT_ID();
    END IF;

    SELECT slot_id, slot_number INTO v_slot_id, p_slot_no
    FROM ParkingSlot
    WHERE lot_id = p_lot_id AND slot_type = p_vtype AND status = 'FREE'
    ORDER BY slot_number
    LIMIT 1
    FOR UPDATE;

    IF v_slot_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No free slot available for this vehicle type in this lot';
    ELSE
        INSERT INTO ParkingSession (vehicle_id, slot_id, entry_time, status)
        VALUES (v_vehicle_id, v_slot_id, NOW(), 'ACTIVE');
        SET p_session_id = LAST_INSERT_ID();
    END IF;
END$$

CREATE PROCEDURE sp_process_exit (
    IN p_session_id INT,
    IN p_payment_mode VARCHAR(10),
    OUT p_amount DECIMAL(8,2)
)
BEGIN
    DECLARE v_vtype VARCHAR(10);
    DECLARE v_entry DATETIME;
    DECLARE v_lot_id INT;
    DECLARE v_rate DECIMAL(6,2);
    DECLARE v_grace INT;
    DECLARE v_minutes INT;
    DECLARE v_billable_hrs INT;

    SELECT v.vehicle_type, s.entry_time, sl.lot_id
    INTO v_vtype, v_entry, v_lot_id
    FROM ParkingSession s
    JOIN Vehicle v ON v.vehicle_id = s.vehicle_id
    JOIN ParkingSlot sl ON sl.slot_id = s.slot_id
    WHERE s.session_id = p_session_id AND s.status = 'ACTIVE';

    IF v_entry IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Session not found or already closed';
    END IF;

    SELECT rate_per_hour, grace_minutes
    INTO v_rate, v_grace
    FROM RateCard
    WHERE lot_id = v_lot_id AND vehicle_type = v_vtype;

    SET v_minutes = TIMESTAMPDIFF(MINUTE, v_entry, NOW());

    IF v_minutes <= v_grace THEN
        SET p_amount = 0.00;
    ELSE
        SET v_billable_hrs = CEIL(v_minutes / 60.0);
        SET p_amount = v_billable_hrs * v_rate;
    END IF;

    UPDATE ParkingSession
    SET exit_time = NOW(), status = 'COMPLETED'
    WHERE session_id = p_session_id;

    INSERT INTO Payment (session_id, duration_mins, amount, payment_mode)
    VALUES (p_session_id, v_minutes, p_amount, p_payment_mode);
END$$

DELIMITER ;

CREATE VIEW vw_lot_occupancy AS
SELECT
    l.lot_id, l.lot_name,
    COUNT(*) AS total_slots,
    SUM(s.status = 'FREE') AS free_slots,
    SUM(s.status = 'OCCUPIED') AS occupied_slots,
    ROUND(SUM(s.status = 'OCCUPIED') / COUNT(*) * 100, 1) AS occupancy_pct
FROM ParkingLot l
JOIN ParkingSlot s ON s.lot_id = l.lot_id
GROUP BY l.lot_id, l.lot_name;

CREATE VIEW vw_daily_revenue AS
SELECT
    DATE(p.payment_time) AS revenue_date,
    COUNT(*) AS transactions,
    SUM(p.amount) AS total_revenue
FROM Payment p
GROUP BY DATE(p.payment_time);

CREATE VIEW vw_active_sessions AS
SELECT
    ps.session_id, v.plate_number, v.vehicle_type,
    pl.lot_name, sl.slot_number,
    ps.entry_time,
    TIMESTAMPDIFF(MINUTE, ps.entry_time, NOW()) AS minutes_parked
FROM ParkingSession ps
JOIN Vehicle v ON v.vehicle_id = ps.vehicle_id
JOIN ParkingSlot sl ON sl.slot_id = ps.slot_id
JOIN ParkingLot pl ON pl.lot_id = sl.lot_id
WHERE ps.status = 'ACTIVE';

-- MASTER DATA
INSERT INTO ParkingLot (lot_name, location, total_slots) VALUES
('City Centre Mall', 'MG Road', 6),
('Tech Park Plaza', 'Cyber Hub', 4);

INSERT INTO ParkingSlot (lot_id, slot_number, slot_type, status) VALUES
(1, 'A1', 'CAR', 'FREE'), (1, 'A2', 'CAR', 'FREE'), (1, 'A3', 'CAR', 'FREE'),
(1, 'B1', 'BIKE', 'FREE'), (1, 'B2', 'BIKE', 'FREE'),
(1, 'H1', 'HANDICAP', 'FREE'),
(2, 'A1', 'CAR', 'FREE'), (2, 'A2', 'CAR', 'FREE'),
(2, 'E1', 'EV', 'FREE'), (2, 'B1', 'BIKE', 'FREE');

INSERT INTO RateCard (lot_id, vehicle_type, rate_per_hour, grace_minutes) VALUES
(1, 'CAR', 40.00, 10),
(1, 'BIKE', 15.00, 10),
(1, 'HANDICAP', 20.00, 15),
(1, 'EV', 50.00, 10),
(2, 'CAR', 50.00, 10),
(2, 'BIKE', 20.00, 10),
(2, 'HANDICAP', 25.00, 15),
(2, 'EV', 60.00, 10);

INSERT INTO Staff (full_name, role, lot_id) VALUES
('Raj Kumar', 'ATTENDANT', 1),
('Priya Sharma', 'SUPERVISOR', 1),
('Amit Verma', 'ATTENDANT', 2),
('Neha Singh', 'SUPERVISOR', 2),
('Vikram Rao', 'ADMIN', 1);

-- SAMPLE VEHICLE MASTER DATA
INSERT INTO Vehicle (plate_number, vehicle_type, owner_name, phone) VALUES
('KA01AB1234', 'CAR', 'Rahul Sharma', '9876543210'),
('KA02CD5678', 'BIKE', 'Anita Rao', '9988776655'),
('KA03EF9999', 'CAR', 'Meera Iyer', '9900112233');

-- SAMPLE SELECT QUERIES
SELECT * FROM ParkingLot;
SELECT * FROM ParkingSlot;
SELECT * FROM Vehicle;
SELECT * FROM RateCard;
SELECT * FROM Staff;
SELECT * FROM vw_lot_occupancy;
SELECT * FROM vw_active_sessions;
SELECT * FROM vw_daily_revenue;

-- DEMO ALLOCATION/BILLING:
-- CALL sp_allocate_slot('KA01AB1234','CAR',1,'Rahul Sharma','9876543210',@slot,@sess);
-- UPDATE ParkingSession SET entry_time = NOW() - INTERVAL 150 MINUTE WHERE session_id=@sess;
-- CALL sp_process_exit(@sess,'UPI',@bill);
-- SELECT @slot AS assigned_slot,@sess AS session_id,@bill AS amount_billed;
