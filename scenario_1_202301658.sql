-- ============================================================
-- ICT371 POSTGRESQL SCENARIO 1
-- UNIVERSITY LIBRARY BOOK LOANS
-- ============================================================

-- Clean previous objects
DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

-- ============================================================
-- 1. CREATE TABLES AND ADD BOOKS
-- ============================================================

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    available_copies INTEGER NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INTEGER REFERENCES books(book_id),
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL,
    loan_status VARCHAR(20) NOT NULL DEFAULT 'BORROWED'
);

INSERT INTO books (title, available_copies)
VALUES
('Database Systems', 10),
('Computer Networks', 5),
('Web Development', 2);

-- Display books
SELECT * FROM books;

-- ============================================================
-- 2. IF ELSIF ELSE
-- ============================================================

DO $$
DECLARE
    copies INTEGER;
BEGIN
    SELECT available_copies
    INTO copies
    FROM books
    WHERE book_id = 1;

    IF copies = 0 THEN
        RAISE NOTICE 'The book is unavailable.';
    ELSIF copies <= 2 THEN
        RAISE NOTICE 'The book is low on copies.';
    ELSE
        RAISE NOTICE 'The book is sufficiently stocked.';
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
        RAISE NOTICE 'Overdue reminder number %', counter;
        counter := counter + 1;
    END LOOP;
END $$;

DO $$
DECLARE
    shelf_number INTEGER;
BEGIN
    FOR shelf_number IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number: %', shelf_number;
    END LOOP;
END $$;

-- ============================================================
-- 4. BORROW_BOOK PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    copies INTEGER;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero.';
    END IF;

    SELECT available_copies
    INTO copies
    FROM books
    WHERE book_id = p_book_id
    FOR UPDATE;

    IF copies IS NULL THEN
        RAISE EXCEPTION 'Book does not exist.';
    END IF;

    IF copies < p_quantity THEN
        RAISE NOTICE 'Not enough copies available.';
        RETURN;
    END IF;

    UPDATE books
    SET available_copies = available_copies - p_quantity
    WHERE book_id = p_book_id;

    INSERT INTO book_loans
    (book_id, student_number, quantity, loan_status)
    VALUES
    (p_book_id, p_student_number, p_quantity, 'BORROWED');

    RAISE NOTICE 'Book successfully borrowed.';
END;
$$;

-- ============================================================
-- 5. TWO VALID LOANS AND ONE INVALID REQUEST
-- ============================================================

CALL borrow_book(1, 'STU001', 2);
CALL borrow_book(2, 'STU002', 1);

-- This exceeds available copies
CALL borrow_book(3, 'STU003', 5);

SELECT * FROM books;
SELECT * FROM book_loans;

-- ============================================================
-- 6. RETURN_BOOK PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE return_book(
    p_loan_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    loan_book INTEGER;
    loan_quantity INTEGER;
    current_status VARCHAR;
BEGIN
    SELECT book_id, quantity, loan_status
    INTO loan_book, loan_quantity, current_status
    FROM book_loans
    WHERE loan_id = p_loan_id
    FOR UPDATE;

    IF loan_book IS NULL THEN
        RAISE NOTICE 'Loan does not exist.';
        RETURN;
    END IF;

    IF current_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan already returned. Copies will not be restored again.';
        RETURN;
    END IF;

    UPDATE books
    SET available_copies = available_copies + loan_quantity
    WHERE book_id = loan_book;

    UPDATE book_loans
    SET loan_status = 'RETURNED'
    WHERE loan_id = p_loan_id;

    RAISE NOTICE 'Book returned successfully.';
END;
$$;

-- Return the first loan twice
CALL return_book(1);
CALL return_book(1);

-- ============================================================
-- 7. EXPLICIT CURSOR
-- ============================================================

DO $$
DECLARE
    book_record RECORD;

    book_cursor CURSOR FOR
        SELECT book_id, title, available_copies
        FROM books
        WHERE available_copies <= 2;
BEGIN
    OPEN book_cursor;

    LOOP
        FETCH book_cursor INTO book_record;
        EXIT WHEN NOT FOUND;

        RAISE NOTICE 'Low stock book: % - Copies: %',
            book_record.title,
            book_record.available_copies;
    END LOOP;

    CLOSE book_cursor;
END $$;

-- ============================================================
-- 8. INVALID ZERO QUANTITY WITH EXCEPTION
-- ============================================================

DO $$
BEGIN
    BEGIN
        CALL borrow_book(1, 'STU004', 0);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Invalid quantity handled: %', SQLERRM;
    END;
END $$;

-- ============================================================
-- 9. FINAL RESULTS
-- ============================================================

SELECT * FROM books ORDER BY book_id;

SELECT * FROM book_loans ORDER BY loan_id;