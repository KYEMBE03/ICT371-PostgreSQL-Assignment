-- ============================================================
-- ICT371 POSTGRESQL SCENARIO 6
-- UNIVERSITY EVENT SEAT BOOKING
-- ============================================================

DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS events CASCADE;

-- ============================================================
-- 1. CREATE TABLES
-- ============================================================

CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    available_seats INTEGER NOT NULL CHECK (available_seats >= 0)
);

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    event_id INTEGER REFERENCES events(event_id),
    student_number VARCHAR(30) NOT NULL,
    number_of_seats INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'BOOKED'
);

INSERT INTO events
(event_name, available_seats)
VALUES
('Graduation Ceremony', 100),
('ICT Conference', 50),
('Career Fair', 10);

SELECT * FROM events;

-- ============================================================
-- 2. IF ELSIF ELSE
-- ============================================================

DO $$
DECLARE
    seats INTEGER;
BEGIN
    SELECT available_seats
    INTO seats
    FROM events
    WHERE event_id = 1;

    IF seats = 0 THEN
        RAISE NOTICE 'Event is full.';
    ELSIF seats <= 10 THEN
        RAISE NOTICE 'Event is nearly full.';
    ELSE
        RAISE NOTICE 'Event has plenty of seats.';
    END IF;
END $$;

-- ============================================================
-- 3. WHILE AND NUMERIC FOR
-- ============================================================

DO $$
DECLARE
    reminder_day INTEGER := 1;
BEGIN
    WHILE reminder_day <= 3 LOOP
        RAISE NOTICE 'Booking reminder day %', reminder_day;
        reminder_day := reminder_day + 1;
    END LOOP;
END $$;

DO $$
DECLARE
    entrance_check INTEGER;
BEGIN
    FOR entrance_check IN 1..3 LOOP
        RAISE NOTICE 'Entrance check number: %', entrance_check;
    END LOOP;
END $$;

-- ============================================================
-- 4. BOOK_SEATS PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE book_seats(
    p_event_id INTEGER,
    p_student_number VARCHAR,
    p_number_of_seats INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    available INTEGER;
BEGIN
    IF p_number_of_seats <= 0 THEN
        RAISE EXCEPTION 'Number of seats must be greater than zero.';
    END IF;

    SELECT available_seats
    INTO available
    FROM events
    WHERE event_id = p_event_id
    FOR UPDATE;

    IF available IS NULL THEN
        RAISE EXCEPTION 'Event does not exist.';
    END IF;

    IF available < p_number_of_seats THEN
        RAISE NOTICE 'Not enough seats available.';
        RETURN;
    END IF;

    UPDATE events
    SET available_seats =
        available_seats - p_number_of_seats
    WHERE event_id = p_event_id;

    INSERT INTO bookings
    (event_id, student_number, number_of_seats, status)
    VALUES
    (p_event_id, p_student_number, p_number_of_seats, 'BOOKED');

    RAISE NOTICE 'Seats booked successfully.';
END;
$$;

-- ============================================================
-- 5. TWO VALID + ONE EXCEEDING REMAINING SEATS
-- ============================================================

CALL book_seats(1, 'STU001', 10);
CALL book_seats(2, 'STU002', 5);

CALL book_seats(3, 'STU003', 20);

SELECT * FROM events;
SELECT * FROM bookings;

-- ============================================================
-- 6. CANCEL_BOOKING PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE cancel_booking(
    p_booking_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    selected_event INTEGER;
    selected_seats INTEGER;
    current_status VARCHAR;
BEGIN
    SELECT event_id, number_of_seats, status
    INTO selected_event, selected_seats, current_status
    FROM bookings
    WHERE booking_id = p_booking_id
    FOR UPDATE;

    IF selected_event IS NULL THEN
        RAISE NOTICE 'Booking does not exist.';
        RETURN;
    END IF;

    IF current_status = 'CANCELLED' THEN
        RAISE NOTICE 'Booking already cancelled. Seats will not be released again.';
        RETURN;
    END IF;

    UPDATE events
    SET available_seats =
        available_seats + selected_seats
    WHERE event_id = selected_event;

    UPDATE bookings
    SET status = 'CANCELLED'
    WHERE booking_id = p_booking_id;

    RAISE NOTICE 'Booking cancelled successfully.';
END;
$$;

CALL cancel_booking(1);
CALL cancel_booking(1);

-- ============================================================
-- 7. EXPLICIT CURSOR
-- ============================================================

DO $$
DECLARE
    event_record RECORD;

    event_cursor CURSOR FOR
        SELECT event_id, event_name, available_seats
        FROM events
        WHERE available_seats <= 10;
BEGIN
    OPEN event_cursor;

    LOOP
        FETCH event_cursor INTO event_record;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE 'Full/nearly full event: % - Seats: %',
            event_record.event_name,
            event_record.available_seats;
    END LOOP;

    CLOSE event_cursor;
END $$;

-- ============================================================
-- 8. ZERO SEATS EXCEPTION
-- ============================================================

DO $$
BEGIN
    BEGIN
        CALL book_seats(1, 'STU004', 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid zero-seat request handled: %', SQLERRM;
    END;
END $$;

-- ============================================================
-- 9. FINAL RESULTS
-- ============================================================

SELECT * FROM events ORDER BY event_id;

SELECT * FROM bookings ORDER BY booking_id;