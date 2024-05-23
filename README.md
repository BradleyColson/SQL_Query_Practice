

The Apple Store Word doc is a set of sql queries about apps in the Apple Store.  It answers imaginary stake holder questions.

create TABLE AppleStore_description_combined AS

SELECT * FROM appleStore_description1

union ALL

SELECT * FROM appleStore_description2

UNION ALL

SELECT * FROM appleStore_description3

UNION all 

SELECT * FROM appleStore_description4

--Check the number of unique apps in tables in the AppleStore.

SELECT count(DISTINCT id) AS UniqueAppIDs
FROM AppleStore

SELECT count(DISTINCT id) AS UniqueAppIDs
FROM AppleStore_description_combined

--check for missing values

SELECT COUNT(*) as MissingValues
FROM AppleStore
where track_name IS null or user_rating is NULL or prime_genre is NULL

SELECT COUNT(*) as MissingValues
FROM AppleStore_description_combined
where app_desc IS null

--Find number of apps per genre.

SELECT prime_genre, count(*) as NumApps
from AppleStore
group by prime_genre
order by NumApps DESC

--Get an overview of app ratings

SELECT 
	min(user_rating) as MinRating,
	max(user_rating) as MaxRating,
    avg(user_rating) as AvgRating
FROM AppleStore

--Determine whether paid apps have higher ratings than free apps in the AppleStore.

SELECT CASE
	when price > 0 then 'Paid'
    else 'Free'
    end as App_Type,
    avg(user_rating) as Avg_Rating
FROM AppleStore
GROUP by App_Type

--Determine if apps with more languages have higher ratings?
SELECT CASE	
		when lang_num < 10 then '<10 languages'
    	when lang_num BETWEEN 10 and 30 THEN '10-30 languages'
    	else '>30 languages'
    end as Language_Bucket,
    avg(user_rating) as Avg_Rating
 from AppleStore
 group BY Language_Bucket
 order by Avg_Rating desc
 
 -- Which genres have the lowest ratings?
 
 SELECT prime_genre,
 		avg(user_rating) as Avg_Rating
 from AppleStore
 group by prime_genre
 order by Avg_Rating aSC
 limit 10
 
 --Is there any correlation between app rating and length of the description in AppleStore?
 
 SELECT CASE
 			when length(b.app_desc) < 500 then 'Short'
            when length(b.app_desc) between 500 and 1000 then 'Medium'
 			ELSE 'Long'
        end as descrition_length_bucket,
        avg(a.user_rating) as Average_Rating
 from AppleStore as A
 Join AppleStore_description_combined as B
 	ON A.id=B.id
group by descrition_length_bucket
order by Average_Rating desc

-- What are the top rated apps for each genre?
SELECT	
	prime_genre,
	track_name,
    user_rating
from (
  	SELECT	
  		prime_genre,
  		track_name,
  		user_rating,
  		rank() over(partition by prime_genre order by user_rating desc, rating_count_tot desc) as rank
        FROM AppleStore
      ) as A
WHERE a.rank= 1  
        
***************************************************************************************************

Used layoff data set with errors.  This is the typical sql quering I used to clean the data.  This is a code along practice with Alex the Analyst.

Cleaned it up using exploration of issues and errors.

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



********************************************************************************



Exploratory data analysis of data from a bank in Portugal.





Unknown isn’t too high here.

[Uploading index.h<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>About Section</title>
<!-- Bootstrap CSS -->
<link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css">

<style>
  .about-section {
    text-align: center;
    padding: 50px 0;
  }
  .about-section h2 {
    font-size: 2.5rem;
    margin-bottom: 20px;
  }
  .about-section img {
    width: 200px; /* Adjust the size as needed */
    height: 200px;
    border-radius: 50%; /* Makes the image round */
    margin-bottom: 20px;
  }
  .about-section p {
    color: #333;
  }

  /* Additional CSS for Projects Section */
.projects-section h2 {
  margin-bottom: 40px;
  font-size: 2.5rem;
}
.card {
  box-shadow: 0 0 10px rgba(0,0,0,0.1); /* Adds a subtle shadow around the card */
}
.card-img-top {
  max-height: 180px; /* Adjust this value to fit the image properly in the card */
  object-fit: cover; /* This makes sure the image covers the area properly */
}
.card-body {
  padding: 15px;
}
.card-title {
  font-size: 1.25rem;
}
.card-text {
  margin-bottom: 15px;
}

/* Additional CSS for Skills Section */
.skills-section h2 {
  margin-bottom: 40px;
  font-size: 2.5rem;
}
.skills-section .card {
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}
.skills-section .card-img-top {
  padding: 20px; /* Add padding around your images if needed */
  background-color: #f8f9fa; /* Adjust the background color if your images have transparent areas */
  height: 180px; /* Fixed height for consistency */
  object-fit: contain; /* This will make sure the image is scaled properly within the container */
}
.skills-section .card-body {
  padding: 15px;
}
.skills-section .card-title {
  font-size: 1.25rem;
  margin-bottom: 15px;
}
.skills-section .btn-outline-primary {
  color: #007bff;
  border-color: #007bff;
}
.skills-section .btn-outline-primary:hover {
  color: #fff;
  background-color: #007bff;
  border-color: #007bff;
}

/* Additional CSS for Contact Section */
.contact-section {
  padding: 50px 0;
}
.contact-section h2 {
  font-size: 2.5rem;
  margin-bottom: 40px;
}
.contact-section p {
  font-size: 1.2rem;
  margin-bottom: 20px;
}
.social-icon {
  width: 50px; /* Size of your icons */
  margin-bottom: 10px;
}
/* Hover effect for icons */
.social-icon:hover {
  opacity: 0.7;
}
/* Style for links in the Contact section */
.contact-section a {
  color: #fff;
  text-decoration: none; /* Removes underline from links */
  display: inline-block; /* Allows for margin on the bottom */
  margin-bottom: 10px;
}
.contact-section a:hover {
  color: #ddd; /* Color when hovering over the link */
}

/* CSS for Sticky Navbar */
.navbar {
  box-shadow: 0 2px 5px rgba(0,0,0,0.2); /* Adds a shadow for depth */
}

/* Ensure padding is added to body to avoid content being hidden behind the navbar */
body { 
  padding-top: 56px; /* Adjust this value based on the height of your navbar */
}

/* Smooth scroll */
html {
  scroll-behavior: smooth;
}

/* Style for navigation bar links */
.navbar-nav .nav-link {
  color: white;
}

.navbar-nav .nav-link:hover {
  color: #f8f9fa; /* Slightly lighter white when hovering over links */
}

/* Media query for responsive navbar collapsing */
@media (max-width: 992px) {
  .navbar-collapse {
    background-color: #343a40; /* Same as navbar color for seamless look */
  }
}


</style>

</head>
<body>

<section id='about' class="about-section">
  <div class="container">
    <h2>About</h2>
    <img src="images/about/1.jpg" alt="About Me">
    <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi sit amet dolor dolor. Suspendisse ligula elit, hendrerit ut bibendum quis, facilisis vitae est. Vivamus vitae felis sit amet sem rhoncus euismod. Praesent commodo lorem porttitor. Nam in condimentum ex. Nam accumsan nisi turpis, sed tempus dolor volutpat non. Proin id enim feugiat ipsum consectetur mattis. Nam blandit venenatis nisi, convallis imperdiet nisi condimentum at.</p>
    <p>Duis convallis ligula sed pretium tristique. Duis nunc risus, lacinia eget cursus id, suscipit ac metus. Sed varius sed tortor congue aliquam. In in dapibus diam, in auctor purus. Praesent vitae tristique diam. Donec tincidunt hendrerit tortor, vitae lobortis purus rutrum sit amet. Nunc non arcu vitae leo rhoncus tincidunt vel sed urna. Sed sed efficitur dui. Morbi id velit nisi. Fusce luctus placerat purus eu cursus.</p>
  </div>
</section>


<!-- Projects Section -->
<section id="projects" class="projects-section bg-light" id="projects">
  <div class="container">
    <h2 class="text-center">Projects</h2>
    <div class="row">
      <!-- Project 1 -->
      <div class="col-md-4 mb-4">
        <div class="card">
          <img src="images/projects/1.jpg" class="card-img-top" alt="Project 1">
          <div class="card-body">
            <h5 class="card-title">Project 1</h5>
            <p class="card-text">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sed nisl erat. Sed et purus ornare, eleifend tellus ut, fermentum arcu.</p>
            <a href="#" class="btn btn-primary">Blog Post</a>
            <a href="#" class="btn btn-secondary">Source Code</a>
          </div>
        </div>
      </div>
      <!-- Project 2 -->
      <div class="col-md-4 mb-4">
        <div class="card">
          <img src="images/projects/2.jpg" class="card-img-top" alt="Project 2">
          <div class="card-body">
            <h5 class="card-title">Project 2</h5>
            <p class="card-text">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sed nisl erat. Sed et purus ornare, eleifend tellus ut, fermentum arcu.</p>
            <a href="#" class="btn btn-primary">Blog Post</a>
            <a href="#" class="btn btn-secondary">Source Code</a>
          </div>
        </div>
      </div>
      <!-- Project 3 -->
      <div class="col-md-4 mb-4">
        <div class="card">
          <img src="images/projects/3.jpg" class="card-img-top" alt="Project 3">
          <div class="card-body">
            <h5 class="card-title">Project 3</h5>
            <p class="card-text">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sed nisl erat. Sed et purus ornare, eleifend tellus ut, fermentum arcu.</p>
            <a href="#" class="btn btn-primary">Blog Post</a>
            <a href="#" class="btn btn-secondary">Source Code</a>
          </div>
        </div>
      </div>
    </div>

  </div>
</section>


<!-- Skills Section -->
<section id="skills" class="skills-section bg-white" id="skills">
  <div class="container">
    <h2 class="text-center">Skills</h2>
    <div class="row">
      <!-- Skill 1 -->
      <div class="col-lg-3 col-md-6 mb-4">
        <div class="card">
          <img src="images/skills/1.png" class="card-img-top" alt="Python">
          <div class="card-body">
            <h5 class="card-title">Python</h5>
            <p class="card-text">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sed nisl erat. Sed et purus ornare, eleifend tellus ut, fermentum arcu.</p>
            <a href="#" class="btn btn-outline-primary">Link to course or bootcamp</a>
          </div>
        </div>
      </div>
      <!-- Skill 2 -->
      <div class="col-lg-3 col-md-6 mb-4">
        <div class="card">
          <img src="images/skills/2.png" class="card-img-top" alt="Data Visualization">
          <div class="card-body">
            <h5 class="card-title">Data Visualization</h5>
            <p class="card-text">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sed nisl erat. Sed et purus ornare, eleifend tellus ut, fermentum arcu.</p>
            <a href="#" class="btn btn-outline-primary">Link to course or bootcamp</a>
          </div>
        </div>
      </div>
      <!-- Skill 3 -->
      <div class="col-lg-3 col-md-6 mb-4">
        <div class="card">
          <img src="images/skills/3.png" class="card-img-top" alt="SQL">
          <div class="card-body">
            <h5 class="card-title">SQL</h5>
            <p class="card-text">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sed nisl erat. Sed et purus ornare, eleifend tellus ut, fermentum arcu.</p>
            <a href="#" class="btn btn-outline-primary">Link to course or bootcamp</a>
          </div>
        </div>
      </div>
      <!-- Skill 4 -->
      <div class="col-lg-3 col-md-6 mb-4">
        <div class="card">
          <img src="images/skills/4.png" class="card-img-top" alt="Data Storytelling">
          <div class="card-body">
            <h5 class="card-title">Data Storytelling</h5>
            <p class="card-text">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec sed nisl erat. Sed et purus ornare, eleifend tellus ut, fermentum arcu.</p>
            <a href="#" class="btn btn-outline-primary">Link to course or bootcamp</a>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- Contact Me Section -->
<section id="contact" class="contact-section text-center text-white bg-dark">
  <div class="container">
    <h2>Contact Me</h2>
    <div class="row">
      <div class="col-lg-6">
        <p><i class="fas fa-envelope"></i> loremipsum@gmail.com</p>
      </div>
      <div class="col-lg-6">
        <p><i class="fas fa-phone"></i> 415xxxxxxx</p>
      </div>
    </div>
    <div class="row">
      <div class="col-lg-2 col-md-4 mb-4">
        <a href="https://linkedin.com/in/yourusername" target="_blank">
          <img src="icons/linkedin.png" alt="LinkedIn" class="social-icon">
          LinkedIn
        </a>
      </div>
      <div class="col-lg-2 col-md-4 mb-4">
        <a href="https://twitter.com/yourusername" target="_blank">
          <img src="icons/twitter.png" alt="Twitter" class="social-icon">
          Twitter
        </a>
      </div>
      <div class="col-lg-2 col-md-4 mb-4">
        <a href="https://github.com/yourusername" target="_blank">
          <img src="icons/github.png" alt="GitHub" class="social-icon">
          GitHub
        </a>
      </div>
      <div class="col-lg-2 col-md-4 mb-4">
        <a href="https://medium.com/@yourusername" target="_blank">
          <img src="icons/medium.png" alt="Medium" class="social-icon">
          Medium
        </a>
      </div>
      <div class="col-lg-2 col-md-4 mb-4">
        <a href="https://youtube.com/c/yourchannel" target="_blank">
          <img src="icons/youtube.png" alt="YouTube" class="social-icon">
          YouTube
        </a>
      </div>
    </div>
  </div>
</section>

<!-- Sticky Navigation Bar -->
<nav class="navbar navbar-expand-lg navbar-dark bg-dark fixed-top">
  <div class="container">
    <a class="navbar-brand" href="#home">Portfolio</a>
    <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarNav">
      <ul class="navbar-nav ml-auto">
        <li class="nav-item">
          <a class="nav-link" href="#home">Home</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="#about">About</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="#projects">Projects</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="#skills">Skills</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="#contact">Contact</a>
        </li>
      </ul>
    </div>
  </div>
</nav>


<!-- Bootstrap JS and dependencies (jQuery and Popper) -->
<script src="https://code.jquery.com/jquery-3.5.1.slim.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/popper.js@1.9.5/dist/umd/popper.min.js"></script>
<script src="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js"></script>
</body>
</html>tml…]()

Unclear why student balances are so high compared to other jobs. I’d have to get this clarified to see if it’s accurate.


The married ratio seems logical.


Yes for housing loan makes sense here.


No personal loan may be low here. 


Of all the exploratory questions so far, this one is the most concerning.

Are cellular and telephone different? Does telephone mean land line?
Why are there so many unknown contacts?



The no for term deposits seems really low.  This is likely concerning. I’d advise marketing about this.



The high count of housing default is alarming.


The personal loan default count looks much better for the bank.

