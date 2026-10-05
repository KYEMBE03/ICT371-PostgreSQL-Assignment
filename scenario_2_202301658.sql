-- ============================================================
-- ICT371 POSTGRESQL SCENARIO 2
-- COMPUTER LABORATORY RESERVATIONS
-- ============================================================

DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS lab_sessions CASCADE;

-- ============================================================
-- 1. CREATE TABLES
-- ============================================================

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100) NOT NULL,
    available_workstations INTEGER NOT NULL CHECK (available_workstations >= 0)
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES lab_sessions(session_id),
    lecturer VARCHAR(100) NOT NULL,
    workstations INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
);

INSERT INTO lab_sessions
(session_name, available_workstations)
VALUES
('Database Practical', 30),
('Networking Practical', 15),
('Programming Practical', 5);

SELECT * FROM lab_sessions;

-- ============================================================
-- 2. IF ELSIF ELSE
-- ============================================================

DO $$
DECLARE
    available INTEGER;
BEGIN
    SELECT available_workstations
    INTO available
    FROM lab_sessions
    WHERE session_id = 1;

    IF available = 0 THEN
        RAISE NOTICE 'Session is full.';
    ELSIF available <= 5 THEN
        RAISE NOTICE 'Session is nearly full.';
    ELSE
        RAISE NOTICE 'Session has enough workstations.';
    END IF;
END $$;

-- ============================================================
-- 3. WHILE AND NUMERIC FOR
-- ============================================================

DO $$
DECLARE
    counter INTEGER := 1;
BEGIN
    WHILE counter <= 3 LOOP
        RAISE NOTICE 'Session preparation reminder %', counter;
        counter := counter + 1;
    END LOOP;
END $$;

DO $$
DECLARE
    workstation INTEGER;
BEGIN
    FOR workstation IN 1..3 LOOP
        RAISE NOTICE 'Workstation check number: %', workstation;
    END LOOP;
END $$;

-- ============================================================
-- 4. RESERVE_WORKSTATIONS PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INTEGER,
    p_lecturer VARCHAR,
    p_workstations INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    available INTEGER;
BEGIN
    IF p_workstations <= 0 THEN
        RAISE EXCEPTION 'Number of workstations must be greater than zero.';
    END IF;

    SELECT available_workstations
    INTO available
    FROM lab_sessions
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF available IS NULL THEN
        RAISE EXCEPTION 'Lab session does not exist.';
    END IF;

    IF available < p_workstations THEN
        RAISE NOTICE 'Not enough workstations available.';
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations =
        available_workstations - p_workstations
    WHERE session_id = p_session_id;

    INSERT INTO reservations
    (session_id, lecturer, workstations, status)
    VALUES
    (p_session_id, p_lecturer, p_workstations, 'ACTIVE');

    RAISE NOTICE 'Workstations reserved successfully.';
END;
$$;

-- ============================================================
-- 5. TWO VALID + ONE EXCEEDING CAPACITY
-- ============================================================

CALL reserve_workstations(1, 'Dr. Banda', 10);
CALL reserve_workstations(2, 'Dr. Phiri', 5);

CALL reserve_workstations(3, 'Dr. Mwansa', 10);

SELECT * FROM lab_sessions;
SELECT * FROM reservations;

-- ============================================================
-- 6. CANCEL_RESERVATION
-- ============================================================

CREATE OR REPLACE PROCEDURE cancel_reservation(
    p_reservation_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    selected_session INTEGER;
    selected_workstations INTEGER;
    current_status VARCHAR;
BEGIN
    SELECT session_id, workstations, status
    INTO selected_session, selected_workstations, current_status
    FROM reservations
    WHERE reservation_id = p_reservation_id
    FOR UPDATE;

    IF selected_session IS NULL THEN
        RAISE NOTICE 'Reservation does not exist.';
        RETURN;
    END IF;

    IF current_status = 'CANCELLED' THEN
        RAISE NOTICE 'Reservation already cancelled. Workstations will not be released again.';
        RETURN;
    END IF;

    UPDATE lab_sessions
    SET available_workstations =
        available_workstations + selected_workstations
    WHERE session_id = selected_session;

    UPDATE reservations
    SET status = 'CANCELLED'
    WHERE reservation_id = p_reservation_id;

    RAISE NOTICE 'Reservation cancelled successfully.';
END;
$$;

CALL cancel_reservation(1);
CALL cancel_reservation(1);

-- ============================================================
-- 7. EXPLICIT CURSOR
-- ============================================================

DO $$
DECLARE
    session_record RECORD;

    session_cursor CURSOR FOR
        SELECT session_id, session_name, available_workstations
        FROM lab_sessions
        WHERE available_workstations <= 5;
BEGIN
    OPEN session_cursor;

    LOOP
        FETCH session_cursor INTO session_record;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE 'Nearly full session: % - Workstations: %',
            session_record.session_name,
            session_record.available_workstations;
    END LOOP;

    CLOSE session_cursor;
END $$;

-- ============================================================
-- 8. ZERO WORKSTATIONS EXCEPTION
-- ============================================================

DO $$
BEGIN
    BEGIN
        CALL reserve_workstations(1, 'Dr. Zero', 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid workstation quantity handled: %', SQLERRM;
    END;
END $$;

-- ============================================================
-- 9. FINAL RESULTS
-- ============================================================

SELECT * FROM lab_sessions ORDER BY session_id;

SELECT * FROM reservations ORDER BY reservation_id;