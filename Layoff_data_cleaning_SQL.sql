-- Data Cleaning Project

-- 1. Remove duplicates
-- 2. Standardize the data
-- 3. Null or blank values
-- 4. Remove any extra columns you created temporarily

-- Create staging table to avoid overriting the raw data

CREATE TABLE layoffs_staging
LIKE layoffs;

-- Make sure it worked
select *
from layoffs_staging;

-- Columns copied over but not data yet

INSERT layoffs_staging
SELECT *
FROM layoffs;

-- Run layoffs_staging to populate the table

-- Create row number to remove duplicates

WITH duplicate_cte as
(
SELECT *,
ROW_NUMBER() OVER(
partition by company, industry, total_laid_off, percentage_laid_off, 'date', stage, country, funds_raised_millions) as row_num
FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- Check if they are actually duplicates or not. Ran a few different company names

select *
from layoffs_staging
where company = '100 Thieves';

-- Remove duplicates
-- copy to clipboard in mysql failed so i created a new table called layoffs staging 2 
-- to create a table of duplicates that is easier to delete

CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` text,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` int
);

-- insert all the data to make a copy of the duplicates to delete safely 

INSERT INTO layoffs_staging2
SELECT *,
ROW_NUMBER() OVER(
partition by company, industry, total_laid_off, percentage_laid_off, 'date', stage, country, funds_raised_millions) as row_num
FROM layoffs_staging;

-- Which ones are duplicates?

select *
from layoffs_staging2
where row_num > 1;

-- Delete duplicate rows from layoffs-staging2

DELETE 
FROM layoffs_staging2
WHERE row_num > 1;

-- Make sure it worked
SELECT *
FROM layoffs_staging2;

-- Step 2. Standardizing data

-- Trim blanks from the front of company name
SELECT company, TRIM(company)
FROM layoffs_staging2;
-- TO update the trimmed company name
UPDATE layoffs_staging2
SET company = TRIM(company);

-- Step 3 find blanks or nulls and fill in what you can

-- Explore any flaws with industry category names
SELECT distinct industry
FROM layoffs_staging2
order by 1;

-- Fix crypto vs crypto currency
SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

-- update to read singularly as crypto
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Look at location, no issues found
SELECT DISTINCT location
FROM layoffs_staging2
order by 1;

-- Look at country
SELECT DISTINCT country
FROM layoffs_staging2
order by 1;

-- Found United States and United States.alter
SELECT distinct country, TRIM(trailing '.' from country)
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET country = TRIM(trailing '.' from country)
WHERE country LIKE 'United States%';

-- Data formatting

SELECT date, 
STR_TO_DATE(date, '%m/%d/%Y') -- Assuming format is mm/dd/yyyy
FROM layoffs_staging2;

-- Update the date format
UPDATE layoffs_staging2
SET date = STR_TO_DATE(date, '%m/%d/%Y');

-- Change date data type
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- Explore for blank or null industry
SELECT DISTINCT industry
FROM layoffs_staging2;

-- Find null or blank industry
SELECT *
FROM layoffs_staging2
WHERE industry IS NUll OR industry = ' ';

-- Self Join to try and fill in missing industry 
SELECT t1.industry, t2.industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
	ON t1.company = t2.company
WHERE (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;

-- The blanks didn't work for this query
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
		on t1.company = t2.company
SET t1.industry = t2.industry
Where (t1.industry IS NULL OR t1.industry = '')
AND t2.industry IS NOT NULL;

-- Change blanks to NULLS
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

--  Try again and remove the blanks while leaving null
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
		on t1.company = t2.company
SET t1.industry = t2.industry
Where t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- This query above worked to populate industry from blank and null

-- Step 4 remove columns you don't need

-- Remove uneeded columns
DELETE 
FROM layoffs_staging2
WHERE total_laid_off IS NULL 
AND percentage_laid_off IS NULL;

-- Is it gone?
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL 
AND percentage_laid_off IS NULL;

-- Remove num_row
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- FInal cleaned data result for this project practice purpose
SELECT *
FROM layoffs_staging2

