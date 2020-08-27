SET client_min_messages = warning;

CREATE LANGUAGE 'plpgsql';

DROP TABLE IF EXISTS book_authors_connect;
DROP TABLE IF EXISTS book_series_connect;
DROP TABLE IF EXISTS publishers CASCADE;
DROP TABLE IF EXISTS paths CASCADE;
DROP TABLE IF EXISTS series CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS formats CASCADE;
DROP TABLE IF EXISTS files CASCADE;
DROP TABLE IF EXISTS books CASCADE;
DROP TABLE IF EXISTS book_params;
DROP TABLE IF EXISTS authors;
DROP TYPE IF EXISTS enum_status_completeness;
DROP TYPE IF EXISTS enum_status_visibility;
DROP TYPE IF EXISTS enum_author_roles;

DROP TABLE IF EXISTS author_roles;
DROP TABLE IF EXISTS book_files CASCADE;

--
-- Update date-fields
--
-- books:
--   date_updated is set to now on any row updates
--
CREATE OR REPLACE FUNCTION book_updated() RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'UPDATE' AND TG_TABLE_NAME = 'books' THEN
		NEW.date_updated = CURRENT_TIMESTAMP;		
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

DROP FUNCTION is_valid_isbn(isbn VARCHAR);
CREATE OR REPLACE FUNCTION is_valid_isbn(isbn VARCHAR) RETURNS BOOLEAN AS '../ebooklib/plsql/is_valid_isbn.so', 'is_valid_isbn' LANGUAGE 'C';

CREATE TABLE publishers
(
  publisher_id       SERIAL,
  name               VARCHAR(100) NOT NULL,
  description        VARCHAR DEFAULT NULL,
  homepage           VARCHAR DEFAULT NULL,

  PRIMARY KEY(publisher_id)
);
CREATE UNIQUE INDEX publishers_name_idx ON publishers(name);

INSERT INTO publishers(name) VALUES('unknown');


CREATE TABLE authors
(
  author_id          SERIAL,
  name               VARCHAR(100) NOT NULL,
  description        VARCHAR DEFAULT NULL,
  homepage           VARCHAR DEFAULT NULL,

  PRIMARY KEY(author_id)
);
CREATE INDEX authors_name_idx ON authors(name);

CREATE TABLE paths
(
  path_id            SERIAL,
  path               VARCHAR UNIQUE NOT NULL,

  PRIMARY KEY(path_id)
);

CREATE TABLE series
(
  series_id          SERIAL,
  name               VARCHAR(255) NOT NULL,

  PRIMARY KEY(series_id)
);


CREATE TABLE categories
(
  category_id        INTEGER UNIQUE NOT NULL,
  parent             INTEGER DEFAULT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
  category           VARCHAR(255) NOT NULL,

  PRIMARY KEY(category_id)
);

INSERT INTO categories(category_id, parent, category) VALUES(1000, NULL, 'Science');
  INSERT INTO categories(category_id, parent, category) VALUES(1010, 1000, 'Astronomy');
  INSERT INTO categories(category_id, parent, category) VALUES(1020, 1000, 'Biology');
    INSERT INTO categories(category_id, parent, category) VALUES(1021, 1020, 'Evolution');
  INSERT INTO categories(category_id, parent, category) VALUES(1030, 1000, 'Mathematics');
  INSERT INTO categories(category_id, parent, category) VALUES(1040, 1000, 'Medicine');
  INSERT INTO categories(category_id, parent, category) VALUES(1050, 1000, 'Physics');

INSERT INTO categories(category_id, parent, category) VALUES(2000, NULL, 'Computers');
  INSERT INTO categories(category_id, parent, category) VALUES(2010, 2000, 'Programming');
  INSERT INTO categories(category_id, parent, category) VALUES(2020, 2000, 'Networking');
  INSERT INTO categories(category_id, parent, category) VALUES(2030, 2000, 'Operating Systems');

CREATE TABLE formats
(
  format_id          SERIAL,
  ext                VARCHAR(20) NOT NULL,
  name               VARCHAR(50) NOT NULL,
  description        VARCHAR(255) NOT NULL,

  PRIMARY KEY(format_id)
);

INSERT INTO formats(ext,name,description) VALUES('pdf',  'Portable Document Format', 'http://www.adobe.com');
INSERT INTO formats(ext,name,description) VALUES('chm',  'Compressed Help File', 'http://www.microsoft.com');
INSERT INTO formats(ext,name,description) VALUES('ps',   'PostScript', 'Try gsview+ghostscript');
INSERT INTO formats(ext,name,description) VALUES('djvu', 'djvu', 'http://windjview.sourceforge.net/');
INSERT INTO formats(ext,name,description) VALUES('pdb',  'PalmDoc', '');

CREATE TYPE enum_author_roles AS ENUM ('unknown','author','editor');
CREATE TYPE enum_status_completeness AS ENUM ('unknown','incomplete', 'complete');
CREATE TYPE enum_status_visibility AS ENUM ('visible','hidden');

CREATE TABLE books
(
  book_id            SERIAL,
  title              VARCHAR NOT NULL,
  subtitle           VARCHAR DEFAULT NULL,
  edition            VARCHAR DEFAULT NULL,
  ISBN13             VARCHAR(13) NOT NULL DEFAULT '' CHECK(ISBN13 = '' OR is_valid_isbn(ISBN13)),
  pages              INTEGER DEFAULT NULL CONSTRAINT has_pages CHECK(pages > 0),

  status             enum_status_completeness NOT NULL DEFAULT 'unknown',
  visibility         enum_status_visibility NOT NULL DEFAULT 'visible',
  quality            INTEGER NOT NULL DEFAULT 0,

  publisher_id       INTEGER REFERENCES publishers(publisher_id) ON DELETE RESTRICT,
  series_id          INTEGER REFERENCES series(series_id) ON DELETE RESTRICT DEFAULT NULL,
  category_id        INTEGER REFERENCES categories(category_id) ON DELETE RESTRICT DEFAULT NULL,

  date_published     DATE DEFAULT NULL,
  date_updated       TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  date_added         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

  PRIMARY KEY(book_id)
);
CREATE TRIGGER book_updated_trigger BEFORE UPDATE ON books FOR EACH ROW EXECUTE PROCEDURE book_updated();
CREATE UNIQUE INDEX book_isbn_idx ON books(ISBN13) WHERE ISBN13 <> '';

CREATE TABLE book_params
(
  book_id            INTEGER NOT NULL REFERENCES books(book_id),
  source             VARCHAR(50) DEFAULT NULL,
  name               VARCHAR(50) NOT NULL,
  value              VARCHAR NOT NULL,

  PRIMARY KEY (book_id,source,name)
);
CREATE UNIQUE INDEX book_params_unique_idx ON book_params(book_id,source,name,value);
-- CREATE INDEX book_params_lookup_idx ON book_params(name,value);

CREATE TABLE files
(
  file_id            SERIAL,
  book_id            INTEGER NOT NULL REFERENCES books(book_id),

  format_id          INTEGER NOT NULL REFERENCES formats(format_id),
  path_base_id       INTEGER NOT NULL REFERENCES paths(path_id),
  path_id            INTEGER NOT NULL REFERENCES paths(path_id),

  file_size          INTEGER NOT NULL,
  file_hash_sha1     VARCHAR(40),
  file_name          VARCHAR NOT NULL,

  date_added         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  date_processed     TIMESTAMP WITH TIME ZONE NOT NULL,

  PRIMARY KEY(file_id)
);
-- CREATE TRIGGER files_updated_trigger BEFORE INSERT ON files FOR EACH ROW EXECUTE PROCEDURE book_updated();
CREATE UNIQUE INDEX files_hash_sha1_idx ON files(file_hash_sha1);

CREATE TABLE book_authors_connect
(
  book_id            INTEGER REFERENCES books(book_id) ON DELETE RESTRICT,
  author_role		 enum_author_roles NOT NULL DEFAULT ('unknown'),
  author_id          INTEGER REFERENCES authors(author_id) ON DELETE RESTRICT,
  PRIMARY KEY(book_id, author_id)
);

CREATE TABLE book_series_connect
(
  book_id            INTEGER REFERENCES books(book_id) ON DELETE RESTRICT,
  series_id          INTEGER REFERENCES series(series_id) ON DELETE RESTRICT,
  PRIMARY KEY(book_id, series_id)
);

GRANT SELECT ON TABLE formats,publishers,authors,books,files,series,book_authors_connect,book_series_connect,categories,paths TO webuser;

RESET client_min_messages;

