# University of São Paulo - São Carlos Institute of Mathematical and Computer Sciences SCC-241 – Database Laboratory

Final Project – P4 Development of the Complete Application

Professor: Caetano Traina Jr. — caetano@icmc.usp.br  
TA: João Victor Cosme Neres de Sousa — joaovneres@usp.br  
1st Semester of 2026

Submission Date: June 22, 2026

## Datasets

## Formula 1 - FIA Database, with cities and airports of the world.

The database schema is in `DB_backup.sql`.

## Final Project Activities

The objective of this work develope a complete application prototype, capable of manipulating data, executing queries, generating reports, and presenting information in an organized and intuitive manner to the user.

The application should be centered on exploring the Formula 1 - FIA Database, using a user-friendly interface and database resources covered during the semester.

## General Instructions and Guidelines

In the development of the tool, the following points must be observed:

- The implementation must consider the version of the structured, loaded, and corrected database throughout the previous activities, especially after the normalization, deduplication, and link adjustment steps carried out in Practical Work T1.
- The information must be presented to the "tool user" intuitively. The names of the columns displayed on screens, tables, dashboards, and reports must be intelligible in Portuguese.
- The technology used for interface development is freely chosen by the group, as long as it allows implementing the requested functionalities and clearly demonstrates interaction with the database.
- The tool must serve three types of users:
  - System Administrator: there is only one, identified as admin;
  - Team: there must be one user for each team stored in the CONSTRUCTORS table, identified by the pattern `<constructor_ref>_c`;
  - Driver: there must be one user for each driver stored in the DRIVERS table, identified by the pattern `<driver_ref>_d`.
- Some of the requested information has already been worked on in previous activities but must now be integrated into a single application.
- The SQL commands used by the application must be explicit in the code. Tools that automate or hide the executed scripts, preventing their analysis during evaluation, must not be used.
- The concepts studied throughout the course must be highlighted in the respective codes, with comments justifying their use, including:
  - procedures and functions;
  - triggers;
  - views;
  - indexes;
  - queries with joins, aggregations, and filters;
  - access control and authentication, when applicable.

## 1 - Manage Users

Access to the tool must be done only from an initial login screen, where each user must be authenticated to access the functionalities available to their user type.

To simplify the development and testing of the prototype, usernames and passwords must follow the standards defined below:

Admin: Can access any information in the database.
Login: admin
Password: admin

Team: Can only access information related to their team and the drivers who race or have raced for it.
Login: <constructor_ref>_c
Password: <constructor_ref>
Example: for team mclaren, the login must be mclaren_c and the password must be mclaren.

Driver: Can only access information related to their own performance.
Login: <driver_ref>_d
Password: <driver_ref>
Example: for driver hamilton, the login must be hamilton_d and the password must be hamilton.

Points that need to be addressed:

1. A table called USERS must be created, containing at least the following attributes:
   userid, login, password, type, original_id
   The login attribute must be unique. The original_id attribute must store the identifier of the corresponding record in the source table, i.e., the driver's or team's identifier. For the administrator user, this attribute can be null.

2. User passwords must be stored in a protected manner. If the implementation uses real DBMS PostgreSQL users, authentication must be configured with SCRAM-SHA-256. If authentication is done directly through the USERS table, passwords must not be stored in plain text.

3. Each user must belong to only one of the following types:
   'Admin', 'Team', or 'Driver'

4. Drivers and teams already registered in the Formula 1 database must also be registered in the USERS table, following the login and password standards defined above.

5. It must be ensured that whenever a driver or team is created or modified in the respective table, the corresponding record in the USERS table is automatically created or updated.

6. A table called USERS_LOG must be created, intended to audit system access activities, including login and logout. Each record must contain at least:
   - the user's userid;
   - the type of action performed, for example 'LOGIN' or 'LOGOUT';
   - the date and time of the action.

## 2 - Tool Screen Flow

The tool's structure must be centered around three main screens, described below. Each screen must present variations according to the type of authenticated user.

Screen 1: Login Screen. Requests user identification and password. After login confirmation, Screen 2 must be presented.

Screen 2: Dashboard Screen. Presents summarized information according to the type of logged-in user and should function as the main navigation screen of the tool. In all variations, it must present:
- the name or identification of the logged-in user;
- the dashboard information corresponding to the user type;
- buttons or links for the actions available to the authenticated user type;

Depending on the user type, the screen must present:
- Admin: user name and highlight of their identification as administrator;
- Team: team name and number of drivers associated with it;
- Driver: name of the associated team and the driver's full name.

Screen 3: Reports Screen. Must present buttons or equivalent resources to request the reports available to the logged-in user type. Whenever a report is requested, the screen must show the corresponding result. After closing a report visualization, the tool must return to Screen 3.

## 3 - Actions Made Available to Users

The actions available depend on the type of authenticated user.

### Admin:
- Register teams: displays a window or form that allows inserting the necessary data to add a new tuple in the CONSTRUCTORS table. The data to be informed are:
  constructor_ref, name, country_id, and wikipedia_url
- Register drivers: displays a window or form that allows inserting the necessary data to add a new driver in the DRIVERS table. The data to be informed are:
  driver_ref, given_name, family_name, date_of_birth, and country_id
- When a new team or driver is registered, the system must automatically insert the respective user in the USERS table, using triggers and following the login and password standards defined earlier.
- If a user with the generated login already exists, the trigger must cancel the operation and prevent inconsistent insertion in the source table.

### Team:
- Query driver by last name: displays a window or form that allows indicating a driver's last name. The program must verify if there is any driver with that last name who has raced for the logged-in team. If there is, the tool must present the driver's full name, date of birth, and the associated country or nationality.
  Tip: to check if a driver has raced for a team, consult the RESULTS table.
- Insert new drivers by file: displays a window or form that allows indicating the name of a file, accessible in the operating system, containing information about one or more drivers.
  - Each line of the file must contain information about one driver.
  - Each driver must have indicated in the file:
    driver_ref, given_name, family_name, date_of_birth, and country_id
  Before insertion, it must be verified that no other driver with the same first and last name exists. If the driver already exists, this must be reported to the user, and the insertion must be canceled.
  The insertion of the driver must create the corresponding record in the DRIVERS table and the respective user in the USERS table. If the group chooses to explicitly record the association between the new driver and the logged-in team, this decision must be described in the report and implemented in a way compatible with the adopted relational schema.

### Driver:
- Driver-type users cannot alter database data. They can only view reports and the dashboard related to the driver themselves.

## 4 - Dashboard Screen Definition

Each user type must have their own dashboard, with specific information for their profile.

### Admin:
1. Total number of drivers, teams, and seasons registered.
2. List of races registered in the most recent season in the database, with circuit, date, time, and number of laps recorded in the results.
3. List of teams that competed in the most recent season in the database, each with the total points obtained.
4. List of drivers who competed in the most recent season in the database, each with the total points obtained.

### Team:
Stored functions or procedures must be created that receive team data as a parameter and return the following information:
1. number of wins for the team, considering the races in which it obtained first position;
2. number of different drivers who have raced for the team;
3. first and last year for which there is data for the team in the database, considering the RESULTS table.

### Driver:
Stored functions or procedures must be created that receive driver data as a parameter and return the following information:
1. first and last year for which there is data for the driver in the database, considering the RESULTS table;
2. for each year the driver competed and for each circuit they raced on:
   - number of points obtained;
   - number of wins, considering the races in which they obtained first position;
   - total number of races they participated in.

## 5 - Reports

Reports must be presented in a comprehensible manner to the respective user type. Applying sorting, filters, and column names that facilitate the interpretation of results is recommended.

Indexes created to assist reports must be indicated in the code and briefly justified in the final report, explaining which filters, joins, or sorts they aim to optimize.

### Admin:
- Report 1: Indicates the number of results by status, showing the status name and its respective count.
- Report 2: Receives a city name and, for each Brazilian city with that name, shows all Brazilian airports that are at most 100 km from the respective city and that are of type 'medium_airport' or 'large_airport'. The report must present:
  - name of the researched city;
  - IATA code of the airport;
  - name of the airport;
  - city where the airport is located;
  - distance between the researched city and the airport;
  - type of airport.
  An index must also be created to assist this query.
- Report 3: Lists all registered teams, each with their respective number of drivers, and generates a hierarchical report in three levels:
  1. total number of races registered;
  2. number of races registered by circuit, with minimum, average, and maximum number of laps recorded in the results;
  3. for each race per circuit, indicates the respective number of laps recorded and the number of participating drivers.

### Team:
Creating stored functions or procedures for each report is recommended, receiving the logged-in team's identifier as a parameter.
- Report 4: Lists the team's drivers and the number of times each achieved first position in a race. Drivers must be identified by their full name. Necessary indexes must be created to assist this query.
  Tip: to check if a driver has raced for a team and if there was a win, consult the RESULTS table.
- Report 5: Lists the number of results by status, showing the status and its count, limited to the scope of the logged-in team.

### Driver:
Creating stored functions or procedures for each report is recommended, receiving the logged-in driver's identifier as a parameter.
- Report 6: Queries the total number of points obtained per year of participation in Formula 1, showing, for each year, the races in which the points were obtained. The information must be restricted to the logged-in driver only. Necessary indexes must be created to assist this query.
- Report 7: Lists the number of results by status in the races the driver participated in, showing the status and the count of each, limited to the scope of the logged-in driver.

## Final Submission

Each team must submit two files on Moodle:

- A .zip file containing:
  - the application source code;
  - the developed SQL scripts;
  - the necessary files to run the prototype;
  - a README file with instructions for running the application and scripts.
- A single concise report, in .pdf format, containing:
  - a description of the implemented functionalities;
  - the database techniques used;
  - the indexes, functions, views, and triggers created;
  - the main decisions made by the group;
  - examples of application usage, preferably with screenshots;
  - the difficulties encountered and how they were addressed.

The code must contain comments that aid understanding of the implementation, especially in the sections related to the concepts covered in the course.

During the project presentation, individual questions may be asked to group members. These questions will make up the individual grade and may address any part of the work.

All members must be able to explain their contribution to the development of the project as a whole, not just an isolated part.

The main evaluation criteria will be:
- implemented functionalities;
- adequate use of SQL and the concepts studied in the course;
- indexes created for relevant functionalities;
- functions, views, and triggers implemented;
- organization and clarity of the code;
- system usability;
- correctness of solutions;
- clarity of justifications presented in the report.

## Attention
- The report must clearly show the decisions adopted by the group and justify the choices made during the project development.
- Handwritten projects will not be accepted, and clear organization of the answers is also an evaluated point.
- Plagiarism will be graded as zero.
- The files must be submitted:
  by 08:00 on June 22, 2026, posting only on moodle e-Disciplinas.

Good work!
