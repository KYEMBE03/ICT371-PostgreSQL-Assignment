-- ============================================================
-- ICT371 POSTGRESQL SCENARIO 5
-- ENGINEERING WORKSHOP TOOL LOANS
-- ============================================================

DROP TABLE IF EXISTS tool_loans CASCADE;
DROP TABLE IF EXISTS tools CASCADE;

-- ============================================================
-- 1. CREATE TABLES
-- ============================================================

CREATE TABLE tools (
    tool_id SERIAL PRIMARY KEY,
    tool_name VARCHAR(100) NOT NULL,
    available_quantity INTEGER NOT NULL CHECK (available_quantity >= 0)
);

CREATE TABLE tool_loans (
    loan_id SERIAL PRIMARY KEY,
    tool_id INTEGER REFERENCES tools(tool_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ISSUED'
);

INSERT INTO tools
(tool_name, available_quantity)
VALUES
('Hammer', 10),
('Screwdriver', 5),
('Spanner', 2);

SELECT * FROM tools;

-- ============================================================
-- 2. IF ELSIF ELSE
-- ============================================================

DO $$
DECLARE
    quantity INTEGER;
BEGIN
    SELECT available_quantity
    INTO quantity
    FROM tools
    WHERE tool_id = 1;

    IF quantity = 0 THEN
        RAISE NOTICE 'Tool is unavailable.';
    ELSIF quantity <= 2 THEN
        RAISE NOTICE 'Tool is low on stock.';
    ELSE
        RAISE NOTICE 'Tool is readily available.';
    END IF;
END $$;

-- ============================================================
-- 3. WHILE AND NUMERIC FOR
-- ============================================================

DO $$
DECLARE
    reminder INTEGER := 1;
BEGIN
    WHILE reminder <= 3 LOOP
        RAISE NOTICE 'Workshop safety reminder %', reminder;
        reminder := reminder + 1;
    END LOOP;
END $$;

DO $$
DECLARE
    inspection INTEGER;
BEGIN
    FOR inspection IN 1..3 LOOP
        RAISE NOTICE 'Tool inspection number: %', inspection;
    END LOOP;
END $$;

-- ============================================================
-- 4. ISSUE_TOOL PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE issue_tool(
    p_tool_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    available INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Tool quantity must be greater than zero.';
    END IF;

    SELECT available_quantity
    INTO available
    FROM tools
    WHERE tool_id = p_tool_id
    FOR UPDATE;

    IF available IS NULL THEN
        RAISE EXCEPTION 'Tool does not exist.';
    END IF;

    IF available < p_quantity THEN
        RAISE NOTICE 'Not enough tools available.';
        RETURN;
    END IF;

    UPDATE tools
    SET available_quantity =
        available_quantity - p_quantity
    WHERE tool_id = p_tool_id;

    INSERT INTO tool_loans
    (tool_id, student_number, quantity, status)
    VALUES
    (p_tool_id, p_student_number, p_quantity, 'ISSUED');

    RAISE NOTICE 'Tool successfully issued.';
END;
$$;

-- ============================================================
-- 5. TWO VALID + ONE EXCEEDING STOCK
-- ============================================================

CALL issue_tool(1, 'STU001', 2);
CALL issue_tool(2, 'STU002', 1);

CALL issue_tool(3, 'STU003', 10);

SELECT * FROM tools;
SELECT * FROM tool_loans;

-- ============================================================
-- 6. RETURN_TOOL PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE return_tool(
    p_loan_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    selected_tool INTEGER;
    selected_quantity INTEGER;
    current_status VARCHAR;
BEGIN
    SELECT tool_id, quantity, status
    INTO selected_tool, selected_quantity, current_status
    FROM tool_loans
    WHERE loan_id = p_loan_id
    FOR UPDATE;

    IF selected_tool IS NULL THEN
        RAISE NOTICE 'Tool loan does not exist.';
        RETURN;
    END IF;

    IF current_status = 'RETURNED' THEN
        RAISE NOTICE 'Tool already returned. Stock will not be added again.';
        RETURN;
    END IF;

    UPDATE tools
    SET available_quantity =
        available_quantity + selected_quantity
    WHERE tool_id = selected_tool;

    UPDATE tool_loans
    SET status = 'RETURNED'
    WHERE loan_id = p_loan_id;

    RAISE NOTICE 'Tool returned successfully.';
END;
$$;

CALL return_tool(1);
CALL return_tool(1);

-- ============================================================
-- 7. EXPLICIT CURSOR
-- ============================================================

DO $$
DECLARE
    tool_record RECORD;

    tool_cursor CURSOR FOR
        SELECT tool_id, tool_name, available_quantity
        FROM tools
        WHERE available_quantity <= 2;
BEGIN
    OPEN tool_cursor;

    LOOP
        FETCH tool_cursor INTO tool_record;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE 'Low availability tool: % - Quantity: %',
            tool_record.tool_name,
            tool_record.available_quantity;
    END LOOP;

    CLOSE tool_cursor;
END $$;

-- ============================================================
-- 8. ZERO TOOLS EXCEPTION
-- ============================================================

DO $$
BEGIN
    BEGIN
        CALL issue_tool(1, 'STU004', 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid zero quantity handled: %', SQLERRM;
    END;
END $$;

-- ============================================================
-- 9. FINAL RESULTS
-- ============================================================

SELECT * FROM tools ORDER BY tool_id;

SELECT * FROM tool_loans ORDER BY loan_id;