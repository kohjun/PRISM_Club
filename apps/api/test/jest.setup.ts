// Runs before test modules load. Point Prisma at the test database.
process.env.DATABASE_URL =
  process.env.DATABASE_URL_TEST ??
  'postgresql://prism:prism@localhost:5433/prism_club_test?schema=public';
process.env.NODE_ENV = 'test';
